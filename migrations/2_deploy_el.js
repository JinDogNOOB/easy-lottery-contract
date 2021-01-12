const EasyLottery = artifacts.require("EasyLottery");

module.exports = function(deployer){
    deployer.deploy(EasyLottery);
};