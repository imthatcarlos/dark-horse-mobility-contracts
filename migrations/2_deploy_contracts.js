var MobilityCampaigns = artifacts.require('./MobilityCampaigns');

var fs = require('fs');
var path = require('path');

module.exports = function(deployer) {
  var networkIdx = process.argv.indexOf('--network');
  var network = networkIdx != -1 ? process.argv[networkIdx + 1] : 'development'

  var filePath = path.join(__dirname, './../contracts.json');
  var data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  // deploy contract
  deployer.deploy(MobilityCampaigns).then(function() {
    data[network]['MobilityCampaigns'] = MobilityCampaigns.address;

    var json = JSON.stringify(data);
    fs.writeFileSync(filePath, json, 'utf8');

    // write to src/ directory as well
    const srcFilePath = path.join(__dirname, './../../mobility-marketplace/src/json/contracts.json');
    fs.writeFileSync(srcFilePath, json, 'utf8');

    // write contract abi
    fs.writeFileSync(
      path.join(__dirname, './../../mobility-marketplace/src/json/MobilityCampaigns.json'),
      JSON.stringify(require('../build/contracts/MobilityCampaigns')),
      'utf8'
    );
  });
};
