import { sample } from 'lodash/collection';
import fleekStorage from '@fleekhq/fleek-storage-js';

const {
  REACT_APP_FLEEK_API_KEY,
  REACT_APP_FLEEK_API_SECRET,
  ADS_DIRECTORY
} = process.env;

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

    const id = sample(this.activeCampaignIds);
    const data = await this.contract.getActiveCampaignUsers(id, { from: this.account });
    const fileData = await fleekStorage.getFileFromHash({ hash: data.ipfsHash });

    return {
      organization: data.organization,
      title: data.title,
      ad: fileData
    };
  }

  // data => { ethAddress, profession, tripsCompleted, timestamp, signature }
  // signature => provided from web3.eth.utils ?
  async onAdRender(key, data) {
    try {
      console.log('writing data...', data);

      const res = await fleekStorage.upload({
        apiKey: REACT_APP_FLEEK_API_KEY,
        apiSecret: REACT_APP_FLEEK_API_SECRET,
        key: `${ADS_DIRECTORY}/${key}/results`,
        bucket: BUCKET,
        data: JSON.stringify(data)
      });

      console.log(`uploaded json data to: ${`${ADS_DIRECTORY}/${key}/results`}`);
      console.log(res.hash);
      return true;
    } catch (error) {
      console.log(error);
      return null;
    }
  }

  // @TODO: ^ log the ad being clicked
  async onAdClick() {

  }

  async withdrawRewards() {
    try {
      await this.contract.withdrawRewards({ from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
  }

  async enableNewUser() {
    try {
      await this.contract.enableNewUser({ from: this.account });
      return true;
    } catch (error) {
      console.log(error);
      return false;
    }
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
