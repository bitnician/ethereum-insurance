const CoronaToken = artifacts.require('CoronaToken');

module.exports = function (deployer) {
  deployer.deploy(CoronaToken);
};
