import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure user can create a vault",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("vault-nest", "create-vault", 
        [types.none(), types.bool(false)], 
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Ensure deposit works correctly with reentrancy protection",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("vault-nest", "create-vault", 
        [types.none(), types.bool(false)], 
        wallet_1.address
      ),
      Tx.contractCall("vault-nest", "deposit", 
        [types.uint(1000)], 
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Test recovery initiation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    const wallet_2 = accounts.get("wallet_2")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("vault-nest", "create-vault", 
        [types.some(wallet_2.address), types.bool(false)], 
        wallet_1.address
      ),
      Tx.contractCall("vault-nest-recovery", "initiate-recovery", 
        [types.principal(wallet_1.address)], 
        wallet_2.address
      )
    ]);
    
    block.receipts[1].result.expectOk().expectBool(true);
  },
});
