const Vault = artifacts.require("Vault");

module.exports = function (deployer) {
  //These addresses are for MainNet
  const _tokenDAI =  "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const _CRVaddress = "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490";
  const _curve3Pool = "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7";
  const _uniRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const _curveFi_LPGauge = "0xFD4D8a17df4C27c1dD245d153ccf4499e806C87D";
  deployer.deploy(Vault,_tokenDAI,_CRVaddress,_curve3Pool,_uniRouter, _curveFi_LPGauge );
};
