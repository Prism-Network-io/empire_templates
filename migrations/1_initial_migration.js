const SweepTemplate = artifacts.require("SweepTemplate");

module.exports = async function (deployer) {
  let sweepContract;
  await deployer.deploy(SweepTemplate, "1000000000000000000000");
  
  sweepContract = await SweepTemplate.deployed();
  console.log("SweepTemplate address: ", sweepContract.address);

  // sweepContract = await SweepTemplate.at("");
  // console.log("sweepContract address: ", sweepContract.address);

  // // await sweepContract.updateSweepablePair("");
  // await sweepContract.sweep("100000", "0x");
};
