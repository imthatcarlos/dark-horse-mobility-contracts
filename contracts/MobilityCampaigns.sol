pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Babylon
 *
 * @dev This contract manages the exchange of hbz tokens for Babylonia tokens, with a locking period
 * in place before tokens can be claimed
 */
contract MobilityCampaigns {
  using SafeMath for uint256;

  struct Campaign {
    address creator;      // the address of the creator
    string organization;
    string category;
    string title;
    string description;
    string ipfsLink;
    uint budgetWei;
    uint createdAt;     // datetime created
    bool isActive;      // set to false when no longer active
  }

  address public graphIndexer;
  uint[] private activeCampaigns;
  Campaign[] private campaigns;
  mapping(address => bool) public dataProviders; // mapping of accounts that share data
  mapping(address => bool) public campaignReceivers; // mapping of accounts that receive campaigns
  mapping(address => uint) public activeCampaignOwners; // mapping of accounts that own campaigns (idx to activeCampaigns)

  modifier onlyGraphIndexer() {
    require(msg.sender == graphIndexer, "msg.sender must be graphIndexer");
    _;
  }

  modifier onlyCampaignReceivers() {
    require(campaignReceivers[msg.sender] == true, 'account must have approved to receive campaigns');
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
  constructor(address _graphIndexer) public {
    // indexing service The Graph
    graphIndexer = _graphIndexer;

    // take care of zero-index for storage array
    campaigns.push(Campaign({
      creator: address(0),
      organization: '',
      category: '',
      title: '',
      description: '',
      ipfsLink: '',
      budgetWei: 0,
      redeemWei: 0,
      createdAt: 0,
      isActive: false
    }));
  }

  /**
   * Do not accept ETH
   */
  receive() external payable {
    require(msg.sender == address(0), "not accepting ETH");
  }

  // creator must send info + ETH
  function createCampaign() public payable noActiveCampaign {
    // assert budget
    // create record in storage, update lookup arrays
    // allocate budget accordingly
  }

  function toggleReceiveCampaign(bool _shouldReceive) external {
    require(campaignReceivers[msg.sender] != _shouldReceive, 'option for _shouldReceive already set');
    campaignReceivers[msg.sender] = _shouldReceive;
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
      string memory description,
      string memory ipfsLink,
      uint budgetWei,
      uint createdAt
    )
  {
    Campaign storage campaign = campaigns[activeCampaigns[activeCampaignOwners[msg.sender]]];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    description = campaign.description;
    ipfsLink = campaign.ipfsLink;
    budgetWei = campaign.budgetWei;
    createdAt = campaign.createdAt;
  }

  // return active campaigns for users
  function getCampaignsUsers()
    external
    view
    onlyCampaignReceivers
    returns(
      string memory title,
      string memory description,
      string memory ipfsLink
    )
  {

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

  // return campaign record
  function _getCampaign(uint idx) internal {

  }

  // make a campaign inactive
  function _removeActiveCampaignAt(uint _idx) internal returns(bool) {
    require(_idx < activeCampaigns.length, 'out of range exception - _idx');
    require(activeCampaigns[_idx] < campaigns.length, 'out of range exception - activeCampaigns[_idx]');
    require(campaigns[activeCampaigns[_idx]].isActive == true, 'campaign must be active');

    campaigns[activeCampaigns[_idx]].isActive = false;
    activeCampaigns[_idx] = activeCampaigns[activeCampaigns.length - 1];
    delete activeCampaigns[activeCampaigns.length - 1];
    activeCampaigns.length--;

    return true;
  }
}
