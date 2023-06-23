const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

let voting;
let dao;

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
    describe("create proposal", function () {
        it("should exist", async function () {
            expect(await voting.dao()).to.equal(dao.address);
        })
    })
})