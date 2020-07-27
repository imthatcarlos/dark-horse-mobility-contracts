import { sample } from 'lodash/collection';
import fleekStorage from '@fleekhq/fleek-storage-js';

class MobilityAdsClient {
  constructor({ web3, account, contract }) {
    this.web3 = web3;
    this.account = account.toLowerCase();
    this.contract = contract;
  }

  async createCampaign(
    organization,
    category,
    title,
    ipfsHash,
    budgetETH
  ) {
    return this.contract.createCampaign(
      inputOrg.current,
      inputCategory,
      inputTitle.current,
      ipfsHash,
      { from: this.account, value: this.web3.utils.toWei(budgetETH.toString()) }
    );
  }

  async getActiveCampaign() {
    return this.contract.getActiveCampaign({ from: this.account });
  }
}

export default MobilityAdsClient;
