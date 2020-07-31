// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title Babylon
 *
 * @dev This contract manages the exchange of hbz tokens for Babylonia tokens, with a locking period
 * in place before tokens can be claimed
 */
contract MobilityCampaigns {
  using SafeMath for uint256;

  event CampaignCreated(address indexed owner, string indexed organization, string title, uint newTotalRewardsWei);
  event CampaignCompleted(address owner, uint indexed campaignId);

  struct Campaign {
    address creator;      // the address of the creator
    string organization;
    string category;
    string title;
    string ipfsHash;
    string key;
    uint budgetWei;
    uint createdAt;                // datetime created
    uint expiresAt;                // datetime when no longer valid
    bool isActive;                 // set to false when no longer active
    uint currentCampaignReceivers; // how many users receiving ads at time of creation
    uint currentRewardsWei;        // how much wei for rewards at time of creation (excluding this one)
  }

  struct RewardOwner {
    address owner;
    uint enabledAt;
    uint enabledAtCampaignIdx;    // fetch all campaigns > this idx
    uint lastRewardAtCampaignIdx;
    uint lastRewardWei;
    uint totalRewardsWei;
  }

  address public graphIndexer;
  uint[] private activeCampaigns;
  Campaign[] private campaigns;
  RewardOwner[] private rewardOwners;

  mapping(address => bool) public dataProviders; // mapping of accounts that share data
  mapping(address => uint) public campaignReceivers; // mapping of accounts that receive campaigns to their rewards data
  mapping(address => uint) public activeCampaignOwners; // mapping of accounts that own campaigns (idx to activeCampaigns)

  uint public MIN_REWARDS_WITHDRAW_WEI = 150000000000000000; // 0.15 ETH
  uint public totalCampaignReceivers;
  uint public totalDataProviders;
  uint public totalRewardsWei;

  modifier onlyGraphIndexer() {
    require(msg.sender == graphIndexer, 'msg.sender must be graphIndexer');
    _;
  }

  modifier onlyCampaignReceivers() {
    require(campaignReceivers[msg.sender] > 0, 'account must have approved to receive campaigns');
    _;
  }

  modifier onlyActiveCampaignOwners() {
    require(activeCampaignOwners[msg.sender] != 0, 'account must have an active campaign');
    _;
  }

  modifier noActiveCampaign() {
    require(activeCampaignOwners[msg.sender] == 0, 'account already has an active campaign');
    _;
  }

  /**
   * Contract constructor
   */
  constructor() public {
    // indexing service The Graph
    // graphIndexer = _graphIndexer;

    totalCampaignReceivers = 0;
    totalDataProviders = 0;

    // take care of zero-index for storage arrays
    campaigns.push(Campaign({
      creator: address(0),
      organization: '',
      category: '',
      title: '',
      ipfsHash: '',
      key: '',
      budgetWei: 0,
      createdAt: 0,
      expiresAt: 0,
      isActive: false,
      currentCampaignReceivers: 0,
      currentRewardsWei: 0
    }));

    rewardOwners.push(RewardOwner({
      owner: address(0),
      enabledAt: 0,
      enabledAtCampaignIdx: 0,
      lastRewardAtCampaignIdx: 0,
      lastRewardWei: 0,
      totalRewardsWei: 0
    }));
  }

  /**
   * Do not accept ETH
   */
  receive() external payable {
    require(msg.sender == address(0), 'not accepting ETH');
  }

  // creator must send info + ETH
  function createCampaign(
    string memory _organization,
    string memory _category,
    string memory _title,
    string memory _ipfsHash,
    string memory _key
  ) public
    payable
    noActiveCampaign
  {
    // assert budget
    require(msg.value > 0, 'value must be greater than 0');

    // @TODO: set expiredAt

    // create record in storage, update lookup arrays
    _createCampaignRecord(
      _organization,
      _category,
      _title,
      _ipfsHash,
      _key
    );
  }

  function getReceiveCampaign(address _a) public view returns (bool) {
    return campaignReceivers[_a] > 0;
  }

  function getProvideData(address _a) public view returns (bool) {
    return dataProviders[_a];
  }

  function enableNewUser() external {
    // sanity check
    require(campaignReceivers[msg.sender] == 0, 'user already registered');

    // add to storage and lookup
    rewardOwners.push(RewardOwner({
      owner: msg.sender,
      enabledAt: block.timestamp,
      enabledAtCampaignIdx: (campaigns.length - 1), // [bogus, real]
      lastRewardAtCampaignIdx: 0,
      lastRewardWei: 0,
      totalRewardsWei: 0
    }));

    campaignReceivers[msg.sender] = rewardOwners.length - 1;
    dataProviders[msg.sender] = true;

    totalCampaignReceivers = totalCampaignReceivers + 1;
    totalDataProviders = totalDataProviders + 1;
  }

  function disableUser() external {
    // sanity check
    require(campaignReceivers[msg.sender] > 0, 'user not registered');

    _removeRewardOwnerAt(campaignReceivers[msg.sender]);
  }

  // return active campaign id for owners
  function getActiveCampaignId()
    external
    view
    onlyActiveCampaignOwners
    returns(uint)
  {
    return activeCampaignOwners[msg.sender];
  }

  // return active campaign for owners
  function getActiveCampaign()
    external
    view
    onlyActiveCampaignOwners
    returns(
      string memory organization,
      string memory category,
      string memory title,
      string memory ipfsHash,
      uint budgetWei,
      uint createdAt
    )
  {
    Campaign storage campaign = campaigns[activeCampaignOwners[msg.sender]];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    ipfsHash = campaign.ipfsHash;
    budgetWei = campaign.budgetWei;
    createdAt = campaign.createdAt;
  }

  function completeCampaign()
    external
    onlyActiveCampaignOwners
  {
    _removeActiveCampaignAt(activeCampaignOwners[msg.sender]);

    emit CampaignCompleted(msg.sender, activeCampaignOwners[msg.sender]);
  }

  // return active campaign ids for receivers
  function getActiveCampaignIdsUsers()
    external
    view
    onlyCampaignReceivers
    returns(uint[] memory)
  {
    return activeCampaigns;
  }


  // return campaign for owners
  function getActiveCampaignUsers(uint _id)
    external
    view
    onlyCampaignReceivers
    returns(
      string memory organization,
      string memory category,
      string memory title,
      string memory ipfsHash,
      string memory key
    )
  {
    Campaign storage campaign = campaigns[_id];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    ipfsHash = campaign.ipfsHash;
    key = campaign.key;
  }

  // return active campaigns
  function getCampaignsIndexer()
    external
    view
    onlyGraphIndexer
    returns(
      string memory organization,
      string memory category,
      string memory title,
      uint createdAt
    )
  {
    Campaign storage campaign = campaigns[activeCampaigns[activeCampaignOwners[msg.sender]]];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    createdAt = campaign.createdAt;
  }

  // allows users to withdraw their rewards based on the number of campaigns that have occurred
  // https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf
  function withdrawRewards() external onlyCampaignReceivers {
    RewardOwner storage rewardOwner = rewardOwners[campaignReceivers[msg.sender]];

    uint prevIdx;
    uint currentIdx = campaigns.length - 1;
    if (rewardOwner.lastRewardAtCampaignIdx == 0) {
      prevIdx = rewardOwner.enabledAtCampaignIdx;
    } else {
      prevIdx = rewardOwner.lastRewardAtCampaignIdx;
    }

    require(currentIdx > rewardOwner.enabledAtCampaignIdx, 'cannot withdraw until at least 1 more campaign has been created');
    require(currentIdx > prevIdx, 'cannot withdraw until at least 1 more campaign has been created');

    Campaign storage campaignI = campaigns[prevIdx];
    Campaign storage campaignJ = campaigns[currentIdx];

    // new rewards added since last time this account withdrew
    uint totalWei = (campaignJ.currentRewardsWei - campaignI.currentRewardsWei) / campaignJ.currentCampaignReceivers;

    // NOTE: we first multiply by 10e8 so to retain precision, then later divide again
    // NOTE: the multiplier logic is so that newcomers don't get all of the funds they COULD HAVE
    //       this creates the situation where not all of the budget is used
    // @TOOD: try to make this ETH recoverable or at least included in some other kind of pool
    uint multiplier = ((currentIdx - rewardOwner.enabledAtCampaignIdx) * 10**8) / currentIdx;
    uint rWei = (totalWei * multiplier) / 10**8;

    // enforce a min before being able to withdraw (save gas)
    require(rWei >= MIN_REWARDS_WITHDRAW_WEI, 'minimum to withdraw not met');

    rewardOwner.lastRewardAtCampaignIdx = currentIdx;
    rewardOwner.lastRewardWei = rWei;
    rewardOwner.totalRewardsWei = rewardOwner.totalRewardsWei + rWei;

    msg.sender.transfer(rWei);
  }

  /**
   * Creates a record for the token exchange
   */
  function _createCampaignRecord(
    string memory _organization,
    string memory _category,
    string memory _title,
    string memory _ipfsHash,
    string memory _key
  )
    internal
  {
    // update total rewards
    totalRewardsWei = totalRewardsWei + msg.value;

    // add to storage and lookup
    campaigns.push(Campaign({
      creator: msg.sender,
      organization: _organization,
      category: _category,
      title: _title,
      ipfsHash: _ipfsHash,
      key: _key,
      budgetWei: msg.value,
      createdAt: block.timestamp, // solium-disable-line security/no-block-members, whitespace
      expiresAt: 0, // @TODO:
      isActive: true,
      currentCampaignReceivers: totalCampaignReceivers,
      currentRewardsWei: totalRewardsWei
    }));

    activeCampaigns.push(campaigns.length - 1);
    activeCampaignOwners[msg.sender] = campaigns.length - 1;

    emit CampaignCreated(msg.sender, _organization, _title, totalRewardsWei);
  }

  // make a campaign inactive
  function _removeActiveCampaignAt(uint _idx) internal {
    require(_idx < activeCampaigns.length, 'out of range exception - _idx');
    require(activeCampaigns[_idx] < campaigns.length, 'out of range exception - activeCampaigns[_idx]');
    require(campaigns[activeCampaigns[_idx]].isActive == true, 'campaign must be active');

    campaigns[activeCampaigns[_idx]].isActive = false;
    activeCampaigns[_idx] = activeCampaigns[activeCampaigns.length - 1];
    delete activeCampaigns[activeCampaigns.length - 1];
  }

  // remove reward owner data from storage
  function _removeRewardOwnerAt(uint _idx) internal {
    require(_idx < rewardOwners.length, 'out of range exception - _idx');

    rewardOwners[_idx] = rewardOwners[rewardOwners.length - 1];
    delete rewardOwners[rewardOwners.length - 1];
  }
}
