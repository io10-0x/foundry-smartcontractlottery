-include .env

build :; forge build
deploy-sepolia :; forge script ./script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --keystore $(KEYSTORE_PATH_SEPOLIA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_TOKEN)
deploy-anvil :; forge script DeployRaffle --rpc-url $(RPC_URL) --keystore $(KEYSTORE_PATH) --broadcast

