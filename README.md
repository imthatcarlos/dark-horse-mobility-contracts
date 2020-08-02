# dark-horse-mobility-contracts (a [HackFS](https://hackfs.com/) project)
Contracts that manage the campaigns that advertisers create, make available for users to retrieve data, and manage reward distribution.

#### Subgraph repo: https://github.com/imthatcarlos/dark-horse-subgraph

#### Main contract functions
- `createCampaign()`: for advertisers on the marketplace app to create ads and make available to users `campaignReceivers`
- `enableNewUser()`: for users of the mobility app to enable data sharing and ad rewards (by being shown ads)
- `getActiveCampaignIdsUsers()`: for users to fetch ids of active campaigns (for selection)
- `getActiveCampaignUsers()`: for users to fetch data on a single campaign (to be rendered)
- `withdrawRewards()`: for users to claim their rewards. based on
```
(totalRewardsAvailable / campaignReceivers) * numCampaignsUserPresentFor
```
- `completeCampaign()`: for advertisers to close their active campaign (after 15 days) and claim refunded budget (NOTE: refund exists because we can't guarantee that all active users will see and ad, and so only if they were in the network can they claim, but they only have claim to the relative number of campaigns they were present for)

#### Getting Started
Uses [truffle](https://www.trufflesuite.com/docs/truffle/overview) for smart contract development
setup + compile
```
npm i truffle -g
yarn
truffle compile
```

start ganache-cli
```
npm run ganache
```

migrate contracts to dev env + copy ABI to `/dark-horse-mobility-marketplace`
```
truffle migrate
```
