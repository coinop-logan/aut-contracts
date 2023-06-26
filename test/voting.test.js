const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

let autID;
let voting;
let dao;
let daoExpander;

async function getCurrentBlockTime() {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    return block.timestamp;
}

describe("Voting", function () {
    before(async function() {
        [memberRole1, memberRole2, memberRole3, nonMember, ...addrs] = await ethers.getSigners();

        const AutID = await ethers.getContractFactory("AutID");
        autID = await AutID.deploy();
        await autID.deployed();

        const DAOTypes = await ethers.getContractFactory("DAOTypes");
        const daoTypes = await DAOTypes.deploy();
        await daoTypes.deployed();

        const SWLegacyMembershipChecker = await ethers.getContractFactory("SWLegacyMembershipChecker");
    
        const sWLegacyMembershipChecker = await SWLegacyMembershipChecker.deploy();
        await sWLegacyMembershipChecker.deployed();

        daoTypes.addNewMembershipChecker(sWLegacyMembershipChecker.address);

        const DAO = await ethers.getContractFactory("SWLegacyDAO");
        dao = await DAO.deploy();
        await dao.deployed();
        await dao.addMember(memberRole1.address);
        await dao.addMember(memberRole2.address);
        await dao.addMember(memberRole3.address);

        const ModuleRegistryFactory = await ethers.getContractFactory("ModuleRegistry");
        const moduleRegistry = await ModuleRegistryFactory.deploy();
    
        const PluginRegistryFactory = await ethers.getContractFactory("PluginRegistry");
        const pluginRegistry = await PluginRegistryFactory.deploy(moduleRegistry.address);

        const DAOExpander = await ethers.getContractFactory("DAOExpander");
        daoExpander = await DAOExpander.deploy(
            memberRole1.address,
            autID.address,
            daoTypes.address,
            1,
            dao.address,
            1,
            "dummyMetadataUrl",
            10,
            pluginRegistry.address
        );
        await daoExpander.deployed();
        await (await autID.connect(memberRole1).mint("user1", "user1url", 1, 3, daoExpander.address)).wait();
        await (await autID.connect(memberRole2).mint("user2", "user2url", 2, 3, daoExpander.address)).wait();
        await (await autID.connect(memberRole3).mint("user3", "user3url", 3, 3, daoExpander.address)).wait();

        const Voting = await ethers.getContractFactory("Voting");
        voting = await Voting.deploy(daoExpander.address, autID.address);
        await voting.deployed();
    });
    describe("proposal creation", function () {
        it("should fail if proposal start is not in the future", async function () {
            const pastTimestamp = await getCurrentBlockTime() - 1;

            await expect(
                voting.createProposal(pastTimestamp, pastTimestamp + 10, "")
            ).to.be.revertedWith("Proposal cannot start in the past");
        });
        it("should fail if proposal end is not after proposal start", async function () {
            const futureTimestamp = await getCurrentBlockTime() + 100;

            await expect(
                voting.createProposal(futureTimestamp, futureTimestamp - 1, "")
            ).to.be.revertedWith("End time must be after start time");
        });
        it("proposal creation should succeed and should return id = 0", async function() {
            const futureTimestamp = await getCurrentBlockTime() + 100;

            const id = await voting.callStatic.createProposal(futureTimestamp, futureTimestamp + 10, "");

            expect(id).to.equal(0);
        });
    });
    describe("proposals and voting", function() {
        let setupTime;
        before(async function() {
            setupTime = await getCurrentBlockTime();
            await (await voting.createProposal(setupTime + 10, setupTime + 20, "prop 1 dummy cid")).wait();
            await (await voting.createProposal(setupTime + 30, setupTime + 100, "prop 2 dummy cid")).wait();
            await (await voting.createProposal(setupTime + 30, setupTime + 500, "prop 3 dummy cid")).wait();
            await (await voting.createProposal(setupTime + 500, setupTime + 600, "prop 4 dummy cid")).wait();
            await helpers.time.increase(35);
        });
        describe("getActiveProposals", function() {
            it("should return only proposals 2 and 3", async function() {
                const activePropIDs = await voting.getActiveProposalIDs();
                expect(activePropIDs.length).to.equal(2);
                expect(activePropIDs[0]).to.equal(1);
                expect(activePropIDs[1]).to.equal(2);
            })
        });
        describe("getProposal", function() {
            it("should revert if id is invalid", async function() {
                await expect(
                    voting.getProposal(4)
                ).to.be.reverted;
            })
            it("should return the proper info for proposal 1", async function() {
                const proposal = await voting.getProposal(0);
                expect(proposal.startTime).to.equal(setupTime + 10);
                expect(proposal.endTime).to.equal(setupTime + 20);
                expect(proposal.cid).to.equal("prop 1 dummy cid");
            })
        });
        describe("Voting constraints", function() {
            it("should not allow a non-member to vote", async function() {
                await expect(
                    voting.connect(nonMember).vote(1, true)
                ).to.be.revertedWith("msg.sender is not a DAO member");
            });
            it("should not allow a member to vote on a closed proposal", async function() {
                await expect(
                    voting.vote(0, true)
                ).to.be.revertedWith("Proposal voting has ended.")
            });
            it("should not allow a member to vote on a proposal in the future", async function() {
                await expect(
                    voting.vote(3, true)
                ).to.be.revertedWith("Proposal voting has not yet started.")
            });
            it("should allow a member to vote once", async function() {
                await (await voting.vote(1, true)).wait();
                expect((await voting.getProposal(1)).yeaCount).to.equal(10);
            });
            it("should not allow a member to vote again", async function() {
                await expect(
                    voting.vote(1, true)
                ).to.be.reverted;
            });
            it("should have correct weights", async function() {
                expect((await voting.getProposal(2)).yeaCount).to.equal(0);
                await (await voting.connect(memberRole1).vote(2, true)).wait();
                expect((await voting.getProposal(2)).yeaCount).to.equal(10); // from the voting weight of 10 from role A
                await (await voting.connect(memberRole2).vote(2, true)).wait();
                expect((await voting.getProposal(2)).yeaCount).to.equal(10 + 20); // voting weights 10 + 20
                await (await voting.connect(memberRole3).vote(2, true)).wait();
                expect((await voting.getProposal(2)).yeaCount).to.equal(10 + 20 + 18); // voting weights 10 + 20 + 18
            })
        })
    });
})