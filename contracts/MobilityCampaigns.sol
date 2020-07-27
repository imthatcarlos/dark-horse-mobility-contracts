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

  event CampaignCreated(address indexed owner, string indexed organization, string title);
  event CampaignCompleted(address owner, uint indexed campaignId);
  event CampaignResultsReleased(uint indexed campaignId, string threadId);

  struct Campaign {
    address creator;      // the address of the creator
    string organization;
    string category;
    string title;
    string ipfsHash;
    uint budgetWei;
    uint createdAt;          // datetime created
    uint expiresAt;          // datetime when no longer valid
    bool isActive;           // set to false when no longer active
    string campaignThreadId; // results of campaign only accessible to the creator
  }

  address public graphIndexer;
  uint[] private activeCampaigns;
  Campaign[] private campaigns;
  mapping(address => bool) public dataProviders; // mapping of accounts that share data
  mapping(address => bool) public campaignReceivers; // mapping of accounts that receive campaigns
  mapping(address => uint) public activeCampaignOwners; // mapping of accounts that own campaigns (idx to activeCampaigns)
  mapping(uint => address[]) private campaignPayouts; // mapping of accounts that receive campaigns

  uint public totalCampaignReceivers;
  uint public totalDataProviders;

  modifier onlyGraphIndexer() {
    require(msg.sender == graphIndexer, 'msg.sender must be graphIndexer');
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
  constructor() public {
    // indexing service The Graph
    // graphIndexer = _graphIndexer;

    totalCampaignReceivers = 0;
    totalDataProviders = 0;

    // take care of zero-index for storage array
    campaigns.push(Campaign({
      creator: address(0),
      organization: '',
      category: '',
      title: '',
      ipfsHash: '',
      budgetWei: 0,
      createdAt: 0,
      expiresAt: 0,
      isActive: false,
      campaignThreadId: ''
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
    string memory _ipfsHash
  ) public
    payable
    noActiveCampaign
  {
    // assert budget
    require(msg.value > 0, 'value must be greater than 0');

    // @TODO: allocate budget accordingly
    // @TODO: set expiredAt

    // create record in storage, update lookup arrays
    _createCampaignRecord(
      _organization,
      _category,
      _title,
      _ipfsHash
    );
  }

  function getReceiveCampaign(address _a) public view returns (bool) {
    return campaignReceivers[_a];
  }

  function getProvideData(address _a) public view returns (bool) {
    return dataProviders[_a];
  }

  function toggleReceiveCampaign(bool _shouldReceive) external {
    require(campaignReceivers[msg.sender] != _shouldReceive, 'option for _shouldReceive already set');
    campaignReceivers[msg.sender] = _shouldReceive;
    if (_shouldReceive) {
      totalCampaignReceivers = totalCampaignReceivers + 1;
    } else {
      totalCampaignReceivers = totalCampaignReceivers - 1;
    }
  }

  function toggleProvideData(bool _shouldProvide) external {
    require(dataProviders[msg.sender] != _shouldProvide, 'option for _shouldProvide already set');
    dataProviders[msg.sender] = _shouldProvide;
    if (_shouldProvide) {
      totalDataProviders = totalDataProviders + 1;
    } else {
      totalDataProviders = totalDataProviders - 1;
    }
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

  /*
   * @TODO: _payouts param is set from indexer reading trips where campaign.createdAt < trip.endAt < campaign.expiredAt
   */
  function completeCampaign(address[] calldata _payouts)
    external
    onlyActiveCampaignOwners
    returns (uint)
  {
    require(_payouts.length > 0, 'array param _payouts cannot be empty');

    campaignPayouts[activeCampaignOwners[msg.sender]] = _payouts;
    campaigns[activeCampaignOwners[msg.sender]].isActive = false;

    emit CampaignCompleted(msg.sender, activeCampaignOwners[msg.sender]);

    return activeCampaignOwners[msg.sender];
  }

  function setCampaignResultsThread(uint _id, string memory _thread)
    public
    onlyGraphIndexer
  {
    // sanity check
    require(campaigns[_id].isActive == false, 'campaign must be completed');
    require(bytes(campaigns[_id].campaignThreadId).length == 0, 'campaignThreadId must not be already set');

    campaigns[_id].campaignThreadId = _thread;

    emit CampaignResultsReleased(_id, _thread);
  }

  function getCampaignResults(uint _id)
    external
    view
    returns (string memory)
  {
    Campaign storage campaign = campaigns[_id];

    require(campaign.creator == msg.sender, 'only campaign owner can view results');
    require(campaign.isActive == false, 'campaign must be completed');

    return campaign.campaignThreadId;
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
      string memory ipfsHash
    )
  {
    Campaign storage campaign = campaigns[_id];
    organization = campaign.organization;
    category = campaign.category;
    title = campaign.title;
    ipfsHash = campaign.ipfsHash;
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

  /**
   * Creates a record for the token exchange
   */
  function _createCampaignRecord(
    string memory _organization,
    string memory _category,
    string memory _title,
    string memory _ipfsHash
  )
    internal
  {
    // add to storage and lookup
    campaigns.push(Campaign({
      creator: msg.sender,
      organization: _organization,
      category: _category,
      title: _title,
      ipfsHash: _ipfsHash,
      budgetWei: msg.value,
      createdAt: block.timestamp, // solium-disable-line security/no-block-members, whitespace
      expiresAt: 0, // @TODO:
      isActive: true,
      campaignThreadId: ''
    }));
    activeCampaigns.push(campaigns.length - 1);
    activeCampaignOwners[msg.sender] = campaigns.length - 1;

    emit CampaignCreated(msg.sender, _organization, _title);
  }

  // make a campaign inactive
  function _removeActiveCampaignAt(uint _idx) internal returns(bool) {
    require(_idx < activeCampaigns.length, 'out of range exception - _idx');
    require(activeCampaigns[_idx] < campaigns.length, 'out of range exception - activeCampaigns[_idx]');
    require(campaigns[activeCampaigns[_idx]].isActive == true, 'campaign must be active');

    campaigns[activeCampaigns[_idx]].isActive = false;
    activeCampaigns[_idx] = activeCampaigns[activeCampaigns.length - 1];
    delete activeCampaigns[activeCampaigns.length - 1];

    return true;
  }
}
