#!/bin/zsh

source .env

EMPTY_UUPS_ADDRESS=0xf3cb746dEF053b2977CA0ABbab0B03246c61a8F7

USDM_ADDRESS=0x13613fb95931D7cC2F1ae3E30e5090220f818032
USDR_ADDRESS=0x83feDBc0B85c6e29B589aA6BdefB1Cc581935ECD

SEPOLIA_CHAIN_ID=11155111
MUMBAI_CHAIN_ID=80001
UNREAL_CHAIN_ID=18233
ARBITRUM_SEPOLIA_CHAIN_ID=421614

USDR_IMPLEMENTATION_ADDRESS_SEPOLIA=$(cast implementation ${USDR_ADDRESS} --rpc-url sepolia)
USDR_IMPLEMENTATION_ADDRESS_MUMBAI=$(cast implementation ${USDR_ADDRESS} --rpc-url polygon_mumbai)
USDR_IMPLEMENTATION_ADDRESS_UNREAL=$(cast implementation ${USDR_ADDRESS} --rpc-url unreal)
USDR_IMPLEMENTATION_ADDRESS_ARBITRUM_SEPOLIA=$(cast implementation ${USDR_ADDRESS} --rpc-url arbitrum_one_sepolia)

LZ_ENDPOINT_SEPOLIA=0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1
LZ_ENDPOINT_MUMBAI=0xf69186dfBa60DdB133E91E9A4B5673624293d8F8
LZ_ENDPOINT_UNREAL=0x83c73Da98cf733B03315aFa8758834b36a195b87
LZ_ENDPOINT_ARBITRUM_SEPOLIA=0x6098e96a28E02f27B1e6BD381f870F1C8Bd169d3

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_MAINNET_KEY} forge verify-contract ${USDR_ADDRESS} \
    lib/tangible-foundation-contracts/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --chain-id ${SEPOLIA_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" ${EMPTY_UUPS_ADDRESS} "0x")

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_POLYGON_KEY} forge verify-contract ${USDR_ADDRESS} \
    lib/tangible-foundation-contracts/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --chain-id ${MUMBAI_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" ${EMPTY_UUPS_ADDRESS} "0x")

FOUNDRY_PROFILE=optimized forge verify-contract ${USDR_ADDRESS} \
    lib/tangible-foundation-contracts/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --chain-id ${UNREAL_CHAIN_ID} \
    --watch \
    --verifier blockscout \
    --verifier-url "https://unreal.blockscout.com/api"

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_ARBITRUM_KEY} forge verify-contract ${USDR_ADDRESS} \
    lib/tangible-foundation-contracts/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --chain-id ${ARBITRUM_SEPOLIA_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" ${EMPTY_UUPS_ADDRESS} "0x")

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_MAINNET_KEY} forge verify-contract ${USDR_IMPLEMENTATION_ADDRESS_SEPOLIA} \
    src/USTB.sol:USTB \
    --chain-id ${SEPOLIA_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint256,address)" ${USDM_ADDRESS} ${SEPOLIA_CHAIN_ID} ${LZ_ENDPOINT_SEPOLIA})

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_POLYGON_KEY} forge verify-contract ${USDR_IMPLEMENTATION_ADDRESS_MUMBAI} \
    src/USTB.sol:USTB \
    --chain-id ${MUMBAI_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint256,address)" ${USDM_ADDRESS} ${SEPOLIA_CHAIN_ID} ${LZ_ENDPOINT_MUMBAI})

FOUNDRY_PROFILE=optimized forge verify-contract ${USDR_IMPLEMENTATION_ADDRESS_UNREAL} \
    src/USTB.sol:USTB \
    --chain-id ${UNREAL_CHAIN_ID} \
    --watch \
    --verifier blockscout \
    --verifier-url "https://unreal.blockscout.com/api"

FOUNDRY_PROFILE=optimized ETHERSCAN_API_KEY=${ETHERSCAN_ARBITRUM_KEY} forge verify-contract ${USDR_IMPLEMENTATION_ADDRESS_ARBITRUM_SEPOLIA} \
    src/USTB.sol:USTB \
    --chain-id ${ARBITRUM_SEPOLIA_CHAIN_ID} \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint256,address)" ${USDM_ADDRESS} ${SEPOLIA_CHAIN_ID} ${LZ_ENDPOINT_ARBITRUM_SEPOLIA})
