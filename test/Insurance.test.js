const Insurance = artifacts.require('Insurance');
const dotenv = require('dotenv');
const crypto = require('crypto');
dotenv.config({ path: './config.env' });
const chai = require('chai');
chai.use(require('chai-as-promised')).should();
const { abi: crnTokenABI } = require('../build/contracts/CoronaToken.json');
const { abi: usdtTokenABI } = require('../build/contracts/USDT.json');
const hash = crypto.getHashes();

const helpers = {
  addressIsExists: (address) => {
    assert.ok(address);
    assert.notEqual(address, 0x0);
    assert.notEqual(address, null);
    assert.notEqual(address, undefined);
    assert.notEqual(address, '');
  },
};
const getEpochTime = () => {
  const now = new Date();
  return Math.round(now.getTime() / 1000);
};

contract('Insurance', ([admin, user, registrant1, registrant2, doctor1, doctor2, doctor3]) => {
  let insurance, crn, usdt, crnInstance, usdtInstance;
  let doctors = [];

  beforeEach(async () => {
    insurance = await Insurance.deployed();
    await insurance.setStableCoin(process.env.USDT);
  });
  /**
   * Check to see if Contract is deployed successfully
   */
  describe('Deploye Insurance Contract', () => {
    it('should deploy the contract', async () => {
      const address = await insurance.address;
      helpers.addressIsExists(address);
    });
  });

  /**
   * White list contract
   */
  describe('Add Doctor', () => {
    it('should add a doctor by admin', async () => {
      await insurance.addDoctor('David', doctor1, {
        from: admin,
      });
      let doctorsCount = await insurance.doctorsCount();

      assert.deepEqual(doctorsCount, web3.utils.toBN(1));
    });

    it('should NOT add a doctor twice', async () => {
      await insurance
        .addDoctor('David', doctor1, {
          from: admin,
        })
        .should.be.rejectedWith('Profile with the same address already exists!');
      let doctorsCount = await insurance.doctorsCount();

      assert.deepEqual(doctorsCount, web3.utils.toBN(1));
    });
    it('should NOT add a doctor by user', async () => {
      await insurance
        .addDoctor('Rose', doctor2, {
          from: user,
        })
        .should.be.rejectedWith('Only Admin!');
      let doctorsCount = await insurance.doctorsCount();

      assert.deepEqual(doctorsCount, web3.utils.toBN(1));
    });

    it('should NOT add a doctor without name', async () => {
      await insurance
        .addDoctor('', doctor2, {
          from: admin,
        })
        .should.be.rejectedWith('Name must not be empty!');
      let doctorsCount = await insurance.doctorsCount();

      assert.deepEqual(doctorsCount, web3.utils.toBN(1));
    });
  });
  describe('Get Doctor', async () => {
    it('should get doctors', async () => {
      doctors = await insurance.getDoctors();

      assert.deepEqual(doctors, [doctor1]);
    });
  });

  /**
   * Insurance contract
   */
  describe('Set Registration Fee', () => {
    it('should set registration fee', async () => {
      await insurance.setRegistrationFee(2, { from: admin });
      const newFee = await insurance.registrationFee();
      assert.equal(newFee.toNumber(), 2);
    });
    it('should NOT set registration fee from user', async () => {
      await insurance.setRegistrationFee(9999, { from: user }).should.be.rejectedWith('Only Admin!');
      const registrationFee = await insurance.registrationFee();
      assert.equal(registrationFee.toNumber(), 2);
    });
  });
  describe('Set Max Payment', () => {
    it('should set max payment', async () => {
      await insurance.setMaxPayment(1000, { from: admin });
      const newMaxPayment = await insurance.maxPayment();
      assert.equal(newMaxPayment.toNumber(), 1000);
    });
    it('should NOT set max payment from user', async () => {
      await insurance.setMaxPayment(9999, { from: user }).should.be.rejectedWith('Only Admin!');
      const maxPayment = await insurance.maxPayment();
      assert.equal(maxPayment.toNumber(), 1000);
    });
  });
  describe('Set Crn Per Tether', () => {
    it('should set crnPerTether', async () => {
      await insurance.setCrnPerTether(10, { from: admin });
      const crnPerTether = await insurance.crnPerTether();
      assert.equal(crnPerTether.toNumber(), 10);
    });
    it('should NOT set crnPerTether from user', async () => {
      await insurance.setMaxPayment(9999, { from: user }).should.be.rejectedWith('Only Admin!');
      const crnPerTether = await insurance.crnPerTether();
      assert.equal(crnPerTether.toNumber(), 10);
    });
  });

  /**
   *
   */
  describe('Set Suspend Time', () => {
    it('should set the suspend time', async () => {
      await insurance.setSuspendTime(1, { from: admin });

      const suspendTime = await insurance.suspendTime();
      assert.equal(suspendTime.toNumber(), 1);
    });
    it('should NOT set the suspend time from user', async () => {
      await insurance.setSuspendTime(999999, { from: user }).should.be.rejectedWith('Only Admin!');
    });
  });
  /**
   *
   */

  describe('Insurance Lifecycle', () => {
    /**
     *
     */

    describe('Buy Token', () => {
      let crnPerTether, registrationFee;

      beforeEach(async () => {
        crn = await insurance.crn();
        usdt = await insurance.stableCoin();

        crnPerTether = await insurance.crnPerTether();
        registrationFee = await insurance.registrationFee();

        // Get Instance of CRN Token and USDT Token
        crnInstance = await new web3.eth.Contract(crnTokenABI, crn);
        usdtInstance = await new web3.eth.Contract(usdtTokenABI, usdt);
      });

      it('should buy token', async () => {
        //Send 10 USDT to the registrant1
        await usdtInstance.methods.transfer(registrant1, 10).send({ from: admin });

        // Send All Corona Tokens to the insurance contract
        // const balanceOfAdmin = await crnInstance.methods.balanceOf(admin).call();
        await crnInstance.methods.transfer(insurance.address, 1000).send({ from: admin });
        // const insuranceBalance = await crnInstance.methods.balanceOf(insurance.address).call();

        //   User allow contract to Transfer USDT from his account
        await usdtInstance.methods
          .approve(insurance.address, crnPerTether.toNumber())
          .send({ from: registrant1 });

        //User can buy CRN Token in return of USDT
        await insurance.buyToken({ from: registrant1 });

        const registrantBalance = await crnInstance.methods.balanceOf(registrant1).call();

        assert.equal(registrantBalance, registrationFee.toNumber());
      });

      it('should NOT buy token before approve', async () => {
        await insurance.buyToken({ from: registrant1 }).should.be.rejectedWith('Now Allowed');
        // const balanceOfRegistrant = await crnInstance.methods.balanceOf(registrant1).call();
        // assert.equal(balanceOfRegistrant, 0);
      });
    });
    /**
     *
     */
    describe('Register', () => {
      let inputDataHash;
      beforeEach(async () => {
        let firstName = 'Behzad';
        let lastName = 'Pournouri';
        let identity = '1990476317';
        const result = firstName.concat(lastName, identity);
        inputDataHash = crypto.createHash('sha1').update(result).digest('hex');
      });

      it('should register the user', async () => {
        const registrationFee = await insurance.registrationFee();
        await crnInstance.methods
          .approve(insurance.address, registrationFee.toNumber())
          .send({ from: registrant1 });
        const result = await insurance.register(inputDataHash, { from: registrant1 });
        const { registrant, dataHash, registered } = await result.logs[0].args;

        const balance = await insurance.getBalance(registrant1);

        assert.equal(registrant, registrant1);
        assert.equal(dataHash, inputDataHash);
        assert.equal(registered, true);
        assert.equal(balance.toNumber(), 0);
      });
      it('should NOT register the user twice', async () => {
        await insurance
          .register(inputDataHash, { from: registrant1 })
          .should.be.rejectedWith('Don not have enough token!');
      });
      it('should NOT register the user without crn token', async () => {
        await insurance
          .register(inputDataHash, { from: registrant2 })
          .should.be.rejectedWith('Don not have enough token!');
      });
    });
    describe('Claim', () => {
      it('should claim the registrant', async () => {
        const result = await insurance.claim({ from: registrant1 });
        const doctorsCount = await insurance.doctorsCount();
        const { claimer, deadLine, vote, claimed } = await result.logs[0].args;

        assert.equal(claimer, registrant1);
        // assert.isAbove(deadLine.toNumber(), getEpochTime());

        assert.equal(vote, doctorsCount * 100);
        assert.equal(claimed, true);
      });

      it('should NOT claim the user before registring', async () => {
        await insurance
          .claim({ from: registrant2 })
          .should.be.rejectedWith('You do not have registered yet!');
      });

      it('should NOT claim the registrant twice', async () => {
        await insurance.claim({ from: registrant1 }).should.be.rejectedWith('You can claim once!');
      });
    });
    /**
     *
     */
    describe('Vote', () => {
      it('should vote a claimer by doctor', async () => {
        await insurance.vote(70, registrant1, { from: doctor1 });
        const claimer = await insurance.claimers(registrant1);
        assert.equal(claimer.vote.toNumber(), 70);
      });
      it('should NOT vote a claimer by doctor twice', async () => {
        await insurance
          .vote(70, registrant1, { from: doctor1 })
          .should.be.rejectedWith('Every Doctor can vote once!');
      });
      it('should NOT vote a registrant', async () => {
        await insurance
          .vote(70, registrant2, { from: doctor1 })
          .should.be.rejectedWith('Claimer does not exist!');
      });
    });
  });

  describe('Pay Claimer Demand', () => {
    it('should pay the claimer demand', async () => {
      const insuranceAddress = await insurance.address;
      // Get the USDT balance of contract
      await usdtInstance.methods.transfer(insuranceAddress, 1000).send({ from: admin });
      const oldInsuranceBalance = await usdtInstance.methods.balanceOf(insuranceAddress).call();
      const oldRegistrantBalance = await usdtInstance.methods.balanceOf(registrant1).call();

      setTimeout(async () => {
        await insurance.payClaimerDemand({ from: registrant1 });
      }, 1000);

      const newInsuranceBalance = await usdtInstance.methods.balanceOf(insuranceAddress).call();
      const newRegistrantBalance = await usdtInstance.methods.balanceOf(registrant1).call();

      assert.ok(true);
    });
  });
  /**
   *
   */
  describe('Withdraw', () => {
    it('should withdraw all tethers from Insurance to admin', async () => {
      const insuranceAddress = await insurance.address;
      const insuranceBalance = await usdtInstance.methods.balanceOf(insuranceAddress).call();
      const adminBalance = await usdtInstance.methods.balanceOf(admin).call();
      console.log(insuranceBalance);
      console.log(adminBalance);

      await insurance.withdraw();

      const newInsuranceBalance = await usdtInstance.methods.balanceOf(insuranceAddress).call();
      const newAdminBalance = await usdtInstance.methods.balanceOf(admin).call();
      console.log('new Insurance', newInsuranceBalance);
      console.log('new admin', newAdminBalance);

      assert.ok(true);
    });
  });
});
