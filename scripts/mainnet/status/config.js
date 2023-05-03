/////////////////////////////
// stAUR 🪐 STATUS Config //
/////////////////////////////

// Goerli test addresses
const AURORA_TOKEN_ADDRESS = "0xCca0C26Be4169d7963fEC984F6EAd5F6e630B288";
const AURORA_PLUS_ADDRESS = "0x8e6aA7a602042879074334bB6c02c40A9385F522";
const STAKING_MANAGER_ADDRESS = "0x2da4A45AE7f78EABce1E3206c85383E9a98529d2";
const STAKED_AURORA_VAULT_ADDRESS = "0xD6a1BEB40523A91B8424C02517219875A5D95c01";
const LIQUIDITY_POOL_ADDRESS = "0x9156273eE2684BE1C9F1064cCE43f30E766c8496";
const DEPOSITORS_ADDRESS = [
  "0xF01d1060Fe27D69D143EB237dbC8235ED3e4FA4f",
  "0x0C32f3824B02EC9B82598Cfe487162463579242F"
];

const DECIMALS = ethers.BigNumber.from(10).pow(18);

// Accounts
async function generateAccounts() {
  const [ owner, operator ] = await ethers.getSigners();

  // Current Contracts Accounts
  const VAULT_ADMIN_ACCOUNT = owner;
  const MANAGER_ADMIN_ACCOUNT = owner;

  const VAULT_OPERATOR_ACCOUNT = operator;
  const MANAGER_OPERATOR_ACCOUNT = operator;

  const DEPOSITOR_ADMIN_ACCOUNT = operator;

  return {
    VAULT_ADMIN_ACCOUNT,
    MANAGER_ADMIN_ACCOUNT,
    VAULT_OPERATOR_ACCOUNT,
    MANAGER_OPERATOR_ACCOUNT,
    DEPOSITOR_ADMIN_ACCOUNT
  };
}


module.exports = {
  generateAccounts,
  DEPOSITORS_ADDRESS,
  AURORA_TOKEN_ADDRESS,
  AURORA_PLUS_ADDRESS,
  STAKING_MANAGER_ADDRESS,
  STAKED_AURORA_VAULT_ADDRESS,
  LIQUIDITY_POOL_ADDRESS,
  DECIMALS
};