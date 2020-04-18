const USDT = artifacts.require('USDT');

module.exports = function (deployer) {
  deployer.deploy(USDT);
};
