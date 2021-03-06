// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title Babylon
 *
 * @dev This contract manages the exchange of hbz tokens for Babylonia tokens, with a locking period
 * in place before tokens can be claimed
 */
contract MobilityCampaigns is Ownable {
  using SafeMath for uint256;

  event UserRegistered(address indexed account, uint enabledAt, uint enabledAtCampaignIdx);
  event CampaignCreated(
    address indexed creator,
    string indexed organization,
    string title,
    string category,
    uint createdAt,
    uint budgetWei,
    uint idx
  );
  event CampaignCompleted(address indexed creator, uint totalCampaignReceivers, uint refundWei, uint idx);
  event UserRewardsWithdrawn(address indexed account, uint rewardsWei, uint totalRewardsWei, uint withdrewAt);

  event CampaignBlacklisted(address indexed creator, uint campaign);
  event CampaignFeatured(address indexed creator, uint campaign, uint rank);

  struct Campaign {
    address creator;      // the address of the creator
    uint idx;             // storage idx
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
    uint currentClaimedWei;
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
  address public adVotingDAO;
  uint[] private activeCampaigns;
  Campaign[] private campaigns;
  RewardOwner[] private rewardOwners;

  mapping(address => bool) public dataProviders; // mapping of accounts that share data
  mapping(address => uint) public campaignReceivers; // mapping of accounts that receive campaigns to their rewards data
  mapping(address => uint) public activeCampaignOwners; // mapping of accounts that own campaigns (idx to activeCampaigns)

  mapping(address => uint) public blacklistedCampaignCreators;
  mapping(uint => uint) public featuredCampaigns;

  uint public EXPIRES_IN_SECONDS = 1296000; // 15 min
  uint public MIN_REWARDS_WITHDRAW_WEI = 150000000000000000; // 0.15 ETH
  uint public totalCampaignReceivers;
  uint public totalDataProviders;
  uint public totalRewardsWei;
  uint public rewardsWithdrawnWei;

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

  modifier onlyVotingDAO() {
    require(msg.sender == adVotingDAO, 'msg.sender must be ad voting DAO');
    _;
  }

  modifier notBlacklisted() {
    require(blacklistedCampaignCreators[msg.sender] == 0, 'account must not have been blacklisted');
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
      currentRewardsWei: 0,
      currentClaimedWei: 0,
      idx: 0
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
    notBlacklisted
    noActiveCampaign
  {
    // assert budget
    require(msg.value > 0, 'value must be greater than 0');

    // @TODO: set expiredAt

    // create record in storage, update lookup arrays
    uint idx = _createCampaignRecord(
      _organization,
      _category,
      _title,
      _ipfsHash,
      _key
    );

    emit CampaignCreated(
      msg.sender,
      _organization,
      _title,
      _category,
      block.timestamp,
      msg.value,
      idx
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
    uint idx = campaigns.length - 1;
    rewardOwners.push(RewardOwner({
      owner: msg.sender,
      enabledAt: block.timestamp,
      enabledAtCampaignIdx: idx, // [bogus, real]
      lastRewardAtCampaignIdx: 0,
      lastRewardWei: 0,
      totalRewardsWei: 0
    }));

    campaignReceivers[msg.sender] = rewardOwners.length - 1;
    dataProviders[msg.sender] = true;

    totalCampaignReceivers = totalCampaignReceivers + 1;
    totalDataProviders = totalDataProviders + 1;

    emit UserRegistered(msg.sender, block.timestamp, idx);
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
      uint createdAt,
      uint expiresAt
    )
  {
    Campaign storage campaign = campaigns[activeCampaignOwners[msg.sender]];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    ipfsHash = campaign.ipfsHash;
    budgetWei = campaign.budgetWei;
    createdAt = campaign.createdAt;
    expiresAt = campaign.expiresAt;
  }

  function calculateRefundedWei()
    external
    view
    onlyActiveCampaignOwners
    returns (uint)
  {
    return _calculateRefundedBudget();
  }

  function completeCampaign()
    external
    onlyActiveCampaignOwners
  {
    // sanity check
    // require(campaigns[activeCampaignOwners[msg.sender]].expiresAt > block.timestamp, 'campaign not yet expired');

    uint idx = activeCampaignOwners[msg.sender];
    uint refund = _calculateRefundedBudget();

    _removeActiveCampaignAt(idx);

    // @TODO: is this the right storage var to update?
    totalRewardsWei = totalRewardsWei - refund;

    msg.sender.transfer(refund);

    emit CampaignCompleted(msg.sender, totalCampaignReceivers, refund, idx);
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

  // return active campaign id for owners
  function getIsCampaignActive(uint _idx)
    public
    view
    returns(bool)
  {
    return campaigns[_idx].isActive;
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

    Campaign storage campaignJ = campaigns[currentIdx];

    // new rewards added since last time this account withdrew
    uint totalWei = (campaignJ.currentRewardsWei - campaigns[prevIdx].currentRewardsWei) / campaignJ.currentCampaignReceivers;

    // NOTE: we first multiply by 10e8 so to retain precision, then later divide again
    // NOTE: the multiplier logic is so that newcomers don't get all of the funds they COULD HAVE
    //       this creates the situation where not all of the budget is used
    // @TOOD: try to make this ETH recoverable or at least included in some other kind of pool
    uint multiplier = ((currentIdx - rewardOwner.enabledAtCampaignIdx) * 10**8) / currentIdx;
    uint rWei = (totalWei * multiplier) / 10**8;

    // enforce a min before being able to withdraw (save gas)
    require(rWei >= MIN_REWARDS_WITHDRAW_WEI, 'minimum to withdraw not met');

    // enforce a min before being able to withdraw (save gas)
    require(rWei <= address(this).balance, 'NOT ENOUGH CONTRACT FUNDS');

    rewardOwner.lastRewardAtCampaignIdx = currentIdx;
    rewardOwner.lastRewardWei = rWei;
    rewardOwner.totalRewardsWei = rewardOwner.totalRewardsWei + rWei;
    rewardsWithdrawnWei = rewardsWithdrawnWei + rWei;

    msg.sender.transfer(rWei);

    emit UserRewardsWithdrawn(msg.sender, rWei, rewardOwner.totalRewardsWei, block.timestamp);
  }

  function isCampaignReceiver(address _account) public view returns (bool) {
    return campaignReceivers[_account] > 0;
  }

  function setAdVotingAddress(address _contract) public onlyOwner {
    adVotingDAO = _contract;
  }

  function blacklistCampaignCreator(uint _id) public onlyVotingDAO {
    Campaign storage campaign = campaigns[_id];

    // blacklist the campaign creator
    blacklistedCampaignCreators[campaign.creator] = _id;

    // refund + close out the campaign
    uint refund = _calculateRefundedBudget();

    _removeActiveCampaignAt(_id);

    activeCampaignOwners[campaign.creator] = 0;

    totalRewardsWei = totalRewardsWei - refund;

    payable(campaign.creator).transfer(refund);

    emit CampaignBlacklisted(campaign.creator, _id);
  }

  function setFeaturedCampaign(uint _id, uint _rank) public onlyVotingDAO {
    require(msg.sender == adVotingDAO, 'Error: only ad voting DAO');

    featuredCampaigns[_id] = _rank;

    emit CampaignFeatured(campaigns[_id].creator, _id, _rank);
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
    returns (uint)
  {
    // update total rewards
    totalRewardsWei = totalRewardsWei + msg.value;

    uint newIdx = campaigns.length;

    // add to storage and lookup
    campaigns.push(Campaign({
      creator: msg.sender,
      organization: _organization,
      category: _category,
      title: _title,
      ipfsHash: _ipfsHash,
      key: _key,
      budgetWei: msg.value,
      createdAt: block.timestamp,
      expiresAt: (block.timestamp + EXPIRES_IN_SECONDS),
      isActive: true,
      currentCampaignReceivers: totalCampaignReceivers,
      currentRewardsWei: totalRewardsWei,
      currentClaimedWei: rewardsWithdrawnWei,
      idx: newIdx
    }));

    activeCampaigns.push(newIdx);
    activeCampaignOwners[msg.sender] = newIdx;

    return newIdx;
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

  function _calculateRefundedBudget() internal view returns(uint) {
    Campaign storage campaignI = campaigns[activeCampaignOwners[msg.sender]];
    Campaign storage campaignJ = campaigns[campaigns.length - 1];

    uint rewardsAvailable = campaignJ.currentRewardsWei - campaignI.currentRewardsWei;

    // no new rewards have been added OR claimed
    if (rewardsAvailable == 0) {
      return campaignJ.currentRewardsWei; // @TODO: maybe should be campaignI.budgetWei
    } else {
      uint multiplier = campaignI.budgetWei / rewardsAvailable; // wei given relative to total available
      uint diffClaimed = campaignJ.currentClaimedWei - campaignI.currentClaimedWei; // wei claimed in between
      return (rewardsAvailable - diffClaimed) * multiplier;
    }
  }
}
