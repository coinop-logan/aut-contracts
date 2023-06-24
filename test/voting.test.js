const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

let voting;
let dao;

async function getCurrentBlockTime() {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    return block.timestamp;
}

describe("Voting", function () {
    before(async function() {
        [aMember, nonMember, ...addrs] = await ethers.getSigners();

        const AutID = await ethers.getContractFactory("AutID");
        const autID = await AutID.deploy();
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
        await dao.addMember(aMember.address);

        const ModuleRegistryFactory = await ethers.getContractFactory("ModuleRegistry");
        const moduleRegistry = await ModuleRegistryFactory.deploy();
    
        const PluginRegistryFactory = await ethers.getContractFactory("PluginRegistry");
        const pluginRegistry = await PluginRegistryFactory.deploy(moduleRegistry.address);

        const DAOExpander = await ethers.getContractFactory("DAOExpander");
        const daoExpander = await DAOExpander.deploy(
            aMember.address,
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

        const Voting = await ethers.getContractFactory("Voting");
        voting = await Voting.deploy(dao.address);
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
        it("should create proposal with id=0 if startTime and endTime valid", async function() {
            const futureTimestamp = await getCurrentBlockTime() + 100;

            const id = await voting.callStatic.createProposal(futureTimestamp, futureTimestamp + 10, "");

            expect(id).to.equal(0);
        })
    });
})