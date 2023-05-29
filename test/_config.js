/////////////////////////////
// Global stAUR 🪐 Config //
/////////////////////////////

require("dotenv").config()

const DECIMALS = ethers.BigNumber.from(10).pow(18);

// AURORA Mainnet addresses
const AURORA_PLUS_ADDRESS = "0xccc2b1aD21666A5847A804a73a41F904C4a4A0Ec";
const AURORA_TOKEN_ADDRESS = "0x8BEc47865aDe3B172A928df8f990Bc7f2A3b9f79";
const DEPOSITOR_00_ADDRESS = "0xf56Baf1EE71fD4d6938c88E1C4bd0422ee768932";
const DEPOSITOR_01_ADDRESS = "0x7ca831De9E59D7414313a1F7a003cc7d011caFE2";
const LIQUIDITY_POOL_ADDRESS = "0x2b22F6ae30DD752B5765dB5f2fE8eF5c5d2F154B";
const STAKED_AURORA_VAULT_ADDRESS = "0xb01d35D469703c6dc5B369A1fDfD7D6009cA397F";
const STAKING_MANAGER_ADDRESS = "0x69e3a362ffD379cB56755B142c2290AFbE5A6Cc8";

// NOTE: the `.env` file only has private keys, not the public address.
// Admin account of the stAUR mainnet wallet - metamask.
const ADMIN_ADDRESS = "0x9DF9F65bfcF4Bc6E0C891Eed41a9766f0bf5C319"
const OPERATOR_ADDRESS = "0xd6E4be59FF015aFeFce9b9a78b1cF61be1027cF1"

// This account has a very large aurora amount, at least on block 92_535_477, Aurora Mainnet | 2023-May-22
const AURORA_WHALE_ADDRESS = "0xb5E12B73fffD9aa5F79bDFE70D985552bb51e29f"

const DEPOSITORS_ADDRESS = [ DEPOSITOR_00_ADDRESS, DEPOSITOR_01_ADDRESS ];

module.exports = {
  ADMIN_ADDRESS,
  AURORA_PLUS_ADDRESS,
  AURORA_TOKEN_ADDRESS,
  AURORA_WHALE_ADDRESS,
  DECIMALS,
  DEPOSITORS_ADDRESS,
  DEPOSITOR_00_ADDRESS,
  DEPOSITOR_01_ADDRESS,
  LIQUIDITY_POOL_ADDRESS,
  OPERATOR_ADDRESS,
  STAKED_AURORA_VAULT_ADDRESS,
  STAKING_MANAGER_ADDRESS
};