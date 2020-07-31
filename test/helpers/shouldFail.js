/**
 * source: zeppelin-solidity/test/helpers/
 */

const { should } = require('./setup');

async function shouldFailWithMessage (promise, message) {
  try {
    await promise;
  } catch (error) {
    if (message) {
      error.message.should.include(message, `Wrong failure type, expected '${message}'`);
    }
    return;
  }

  should.fail('Expected failure not received');
}

async function reverting (promise) {
  await shouldFailWithMessage(promise, 'revert');
}

async function throwing (promise) {
  await shouldFailWithMessage(promise, 'invalid opcode');
}

async function outOfGas (promise) {
  await shouldFailWithMessage(promise, 'out of gas');
}

// https://stackoverflow.com/questions/52956509/uncaught-error-returned-values-arent-valid-did-it-run-out-of-gas
async function invalidValues (promise) {
  await shouldFailWithMessage(promise, 'values aren\'t valid');
}

async function shouldFail (promise) {
  await shouldFailWithMessage(promise);
}

shouldFail.reverting = reverting;
shouldFail.throwing = throwing;
shouldFail.outOfGas = outOfGas;
shouldFail.invalidValues = invalidValues;

module.exports = shouldFail;
