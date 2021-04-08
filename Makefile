build :; DAPP_SRC=contracts DAPP_BUILD_OPTIMIZE=0 DAPP_BUILD_OPTIMIZE_RUNS=0 dapp --use solc:0.6.11 build
test  :; DAPP_SRC=contracts DAPP_BUILD_OPTIMIZE=0 DAPP_BUILD_OPTIMIZE_RUNS=0 dapp --use solc:0.6.11 test -v ${TEST_FLAGS}
clean :; DAPP_SRC=contracts dapp clean
