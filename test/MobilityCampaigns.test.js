const MobilityCampaigns = artifacts.require('./MobilityCampaigns.sol');

const shouldFail = require('./helpers/shouldFail');
const increaseTime = require('./helpers/increaseTime');

/**
 * Create instance of contracts
 */
async function setupContract(owner) {
  return await MobilityCampaigns.new({ from: owner });
}

function calculatedReward() {

}

contract('MobilityCampaigns', (accounts) => {
  before(async ()=> {
    web3.currentProvider.sendAsync = web3.currentProvider.send.bind(web3.currentProvider);
  });

  describe('constructor()', () => {
    it('initializes storage variables', async() => {
      var contract = await setupContract(accounts[0]);

      assert.equal(await contract.totalDataProviders(), 0, 'storage initialized');
    });
  });

  describe('business logic', () => {
    it('allows users to sign up for rewards', async() => {
      var contract = await setupContract(accounts[0]);
      await contract.enableNewUser({ from: accounts[1] });

      assert.equal(parseInt(await contract.totalCampaignReceivers()), 1, 'totalCampaignReceivers storage variable was updated');
    });

    it('allows users to create campaigns', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.1', 'ether') }
      );

      const id = await contract.getActiveCampaignId({ from: accounts[1] });

      assert.equal(parseInt(id), 1, 'new campaign added to storage');
    });

    it('allows users to withdraw rewards', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.enableNewUser({ from: accounts[2] });
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.3') }
      );
      const balancePrev = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      await contract.withdrawRewards({ from: accounts[2] });

      const balance = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      assert.equal(Number(parseFloat(balance - balancePrev).toFixed(1)), 0.3, 'user received full reward amount');
    });

    it('allows 2 users to withdraw rewards', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.enableNewUser({ from: accounts[2] });
      await contract.enableNewUser({ from: accounts[3] });
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.3') }
      );
      const balancePrev = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      await contract.withdrawRewards({ from: accounts[2] });
      await contract.withdrawRewards({ from: accounts[3] });

      const balance = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      assert.equal(Number(parseFloat(balance - balancePrev).toFixed(2)), 0.15, 'user received half reward amount');
    });

    it('fairly distributes rewards; early users get ALL rewards vs post-campaign users', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.enableNewUser({ from: accounts[2] });
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.3') }
      );
      await contract.enableNewUser({ from: accounts[3] });

      const balancePrev = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      await contract.withdrawRewards({ from: accounts[2] });

      const balance = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      assert.equal(Number(parseFloat(balance - balancePrev).toFixed(1)), 0.3, 'user received all reward amount');
    });

    it('fairly distributes rewards; early users get ALL rewards vs post-campaign users', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.enableNewUser({ from: accounts[2] }); // (2 - 0) + 1
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.3') }
      );
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[4], value: web3.utils.toWei('0.3') }
      );
      await contract.enableNewUser({ from: accounts[3] }); // (2 - 2) + 1

      const balancePrev = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      await contract.withdrawRewards({ from: accounts[2] });

      const balance = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      assert.equal(Number(parseFloat(balance - balancePrev).toFixed(1)), 0.6, 'user received all reward amount');
    });

    it('fairly distributes rewards; early users get MOST rewards vs post-campaign users', async() => {
      var contract = await setupContract(accounts[0]);

      await contract.enableNewUser({ from: accounts[2] });
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[1], value: web3.utils.toWei('0.3') }
      );
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[4], value: web3.utils.toWei('0.3') }
      );
      await contract.enableNewUser({ from: accounts[3] });
      await contract.createCampaign(
        'nike',
        'fashion',
        'new shoes',
        '0xipfshash',
        'obj-key',
        { from: accounts[5], value: web3.utils.toWei('0.3') }
      );

      const balancePrev = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      await contract.withdrawRewards({ from: accounts[2] });

      const balance = web3.utils.fromWei(await web3.eth.getBalance(accounts[2]), 'ether');
      assert.equal(Number(parseFloat(balance - balancePrev).toFixed(2)), 0.45, 'user received all reward amount');
    });
  });
});
