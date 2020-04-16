//Insurance Contract
const Insurance = artifacts.require('Insurance');
//Token Contract
const CRN = artifacts.require('CoronaToken');

module.exports = (deployer) => {
  deployer.deploy(CRN).then(() => {
    return deployer.deploy(Insurance, 15, 100, CRN.address);
  });
};
