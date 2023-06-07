// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy

    // We get the contract to deploy
    const pluginRegistryAddress = "0xB59d5139540f765963e67cDaE5ea83C7DCA76c13"; // mumbai
    const PluginRegistry = await hre.ethers.getContractFactory("PluginRegistry");
    const pluginRegistry = await PluginRegistry.attach(pluginRegistryAddress);
    const onboardingIpfsUrl = "ipfs://bafkreid63tstlztoeyzm4rquwkdqlbmxaw3wb3d3v6xtajjthrfrafbavy";
    const discordUrl = "ipfs://bafkreignftmez5sjhr7i3a5aqx3cwvnfqsu7kn4uz6ndsrvak7q7jfpwmi";
    const openTaskUrl = "ipfs://bafkreibuwgmzj43xffbmmc4ztbguawobofw4eewtlrtrpllt766ohwfhwm";
    const quizUrl = "ipfs://bafkreie24di5e6lci4ro7tdno2c425tbk3vxxjxer4zdhvajrn7a3ypxgy";
    const transactionTaskUrl = "ipfs://bafkreihv6y7sbwoa6rwrpsvqx2j2n6spomdvuadw72jma4tvzy6oqw44gq";
    const a = await (
        await pluginRegistry.addPluginDefinition(
            '0xa5332a8BFeaff6AD8c195A3EC55F46a028ca02cC', onboardingIpfsUrl, 0, true, [3])
    ).wait();
    console.log("addPluginDefinition", a);
    const b = await (
        await pluginRegistry.addPluginDefinition(
            '0xa5332a8BFeaff6AD8c195A3EC55F46a028ca02cC', discordUrl, 0, true, [])
    ).wait();
    console.log("addPluginDefinition", b);

    const c = await (
        await pluginRegistry.addPluginDefinition(
            '0xa5332a8BFeaff6AD8c195A3EC55F46a028ca02cC', openTaskUrl, 0,  true, [])
    ).wait();
    console.log("addPluginDefinition", c);

    const d = await (
        await pluginRegistry.addPluginDefinition(
            '0xa5332a8BFeaff6AD8c195A3EC55F46a028ca02cC', quizUrl, 0,  true, [])
    ).wait();
    console.log("addPluginDefinition", d);

    const e = await (
        await pluginRegistry.addPluginDefinition(
            '0xa5332a8BFeaff6AD8c195A3EC55F46a028ca02cC', transactionTaskUrl, 0, true, [])
    ).wait();
    console.log("addPluginDefinition", e);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
