import { sample } from 'lodash/collection';
import fleekStorage from '@fleekhq/fleek-storage-js';

class MobilityAdsClient {
  constructor({ web3, account, contract }) {
    this.web3 = web3;
    this.account = account.toLowerCase();
    this.contract = contract;
  }

  async init() {
    const [didEnableAds, didProvideData] = await Promise.all([
      this.contract.getReceiveCampaign(this.account, { from: this.account }),
      this.contract.getProvideData(this.account, { from: this.account })
    ]);

    this.didEnableAds = didEnableAds;
    this.didProvideData = didProvideData;

    if (didEnableAds) {
      this.activeCampaignIds = await this.contract.getActiveCampaignIdsUsers({ from : this.account });
    }

    // @TODO: retrieve from private thread?
    if (this.didProvideData || this.didEnableAds) {
      this.profile = null;
    }
  }

  // 1. select id from activeCampaignIds based on some algo
  // 2. retrieve data from contract
  // 3. retrieve ipfs file data
  async getAd() {
    if (!this.didEnableAds) { return; } // sanity check

    const id = sample(this.activeCampaignIds); // @TODO: some ad auction algo
    const data = await this.contract.getActiveCampaignUsers(id, { from: this.account });
    const fileData = await fleekStorage.getFileFromHash({ hash: data.ipfsHash });

    return {
      organization: data.organization,
      title: data.title,
      ad: fileData
    };
  }

  // @TODO: log a record of the ad (id, timestamp, ipfsHash, account) being rendered
  // @NOTE: this ideally is stored in a secret thread that will eventually be shared with the campaign owner
  async onAdRender() {

  }

  // @TODO: ^ log the ad being clicked
  async onAdClick() {

  }

  async enableAds() {
    try {
      await this.contract.toggleReceiveCampaign(true, { from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
  }

  async disableAds() {
    try {
      await this.contract.toggleReceiveCampaign(false, { from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
  }

  async enableDataShare() {
    try {
      await this.contract.toggleProvideData(true, { from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
  }

  async disableDataShare() {
    try {
      await this.contract.toggleProvideData(false, { from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
  }
}

export default MobilityAdsClient;
