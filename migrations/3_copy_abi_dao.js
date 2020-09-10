var MobilityCampaigns = artifacts.require('./MobilityCampaigns');

var fs = require('fs');
var path = require('path');

module.exports = function(deployer) {
  // write contract abi
  fs.writeFileSync(
    path.join(__dirname, './../../mobility-ads-dao/artifacts/MobilityCampaigns.json'),
    JSON.stringify(require('../build/contracts/MobilityCampaigns')),
    'utf8'
  );

  console.log('copied artifact to ./../mobiltiy-ads-dao');
};
