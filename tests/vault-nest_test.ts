[Previous test content remains, adding new tests...]

Clarinet.test({
  name: "Test vault configuration updates",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("vault-nest", "create-vault", 
        [types.none(), types.bool(false)], 
        wallet_1.address
      ),
      Tx.contractCall("vault-nest", "update-vault-config", 
        [types.uint(100), types.uint(1000000)], 
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk().expectBool(true);
  },
});
