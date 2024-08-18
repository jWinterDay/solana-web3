/// Imports
/// ------------------------------------------------------------------------------------------------

// ignore_for_file: unused_local_variable, avoid_print

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solana_web3/solana_web3.dart';
import 'package:solana_web3/src/programs/address_lookup_table/program.dart';
import 'package:solana_web3/src/programs/address_lookup_table/state.dart';
import 'package:solana_web3/src/programs/system/program.dart';

import 'utils.dart';

/// Transaction Tests
/// ------------------------------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /// Cluster connections.
  final cluster = Cluster.devnet;
  final connection = Connection(cluster);

  final sender = wallet;
  final receiver = Keypair.generateSync();
  const transferAmount = 0.01;

  Future<void> _fundSender() async {
    final int balance = await connection.getBalance(sender.pubkey);
    print('SENDER BALANCE $balance ${sender.pubkey.toBase58()}');
    if (balance < lamportsPerSol) {
      await connection.requestAndConfirmAirdrop(sender.pubkey, lamportsPerSol * 2,
          config: const CommitmentConfig(
            commitment: Commitment.finalized,
          ));
    }

    final int balancex = await connection.getBalance(sender.pubkey);
    print('SENDER BALANCE X $balancex');
  }

  Future<TransactionInstruction> _transferIx() async {
    await _fundSender();
    return SystemProgram.transfer(
      fromPubkey: sender.pubkey,
      toPubkey: receiver.pubkey,
      lamports: solToLamports(transferAmount),
    );
  }

  Future<void> _sendAndConfirmTransferTx(final Transaction tx) async {
    final String signature = await connection.sendTransaction(tx);
    print('TX SEND $signature');
    await connection.confirmTransaction(signature);
    print('GET BALANCE...');
    final int receiverBalance = await connection.getBalance(receiver.pubkey);
    expect(receiverBalance, solToLamports(transferAmount).toInt());
  }

  test('legacy', () async {
    final blockhash = await connection.getLatestBlockhash();
    final TransactionInstruction txIx = await _transferIx();
    final Transaction tx = Transaction.legacy(
      payer: sender.pubkey,
      recentBlockhash: blockhash.blockhash,
      instructions: [txIx],
    );
    tx.sign([sender]);
    await _sendAndConfirmTransferTx(tx);
  });

  test('v0', () async {
    final blockhash = await connection.getLatestBlockhash();
    final TransactionInstruction txIx = await _transferIx();
    final Transaction tx = Transaction.v0(
      payer: sender.pubkey,
      recentBlockhash: blockhash.blockhash,
      instructions: [txIx],
    );
    tx.sign([sender]);
    await _sendAndConfirmTransferTx(tx);
  });

  test('lookup', () async {
    final slot = await connection.getSlot();
    final lookup = AddressLookupTableProgram.findAddressLookupTable(sender.pubkey, slot.toBigInt());
    final blockhash = await connection.getLatestBlockhash();
    final Transaction tx0 = Transaction.v0(
      payer: sender.pubkey,
      recentBlockhash: blockhash.blockhash,
      instructions: [
        AddressLookupTableProgram.create(
          address: lookup,
          authority: sender.pubkey,
          payer: sender.pubkey,
          recentSlot: slot.toBigInt(),
        ),
        AddressLookupTableProgram.extend(
          address: lookup.pubkey,
          authority: sender.pubkey,
          payer: sender.pubkey,
          addresses: [
            Keypair.generateSync().pubkey,
            Keypair.generateSync().pubkey,
          ],
        ),
      ],
    );
    print('LOOKUP ADDRESS ${lookup.pubkey}');
    tx0.sign([sender]);
    await connection.sendAndConfirmTransaction(tx0);
    // final Transaction tx1 = Transaction.v0(
    //   payer: sender.pubkey,
    //   recentBlockhash: blockhash.blockhash,
    //   instructions: [
    //   ],
    // );
    // tx1.sign([sender]);
    // await connection.sendAndConfirmTransaction(tx1);
  });

  test('get lookup', () async {
    final Pubkey address = Pubkey.fromBase58('5rWvmn5jjiuxXpAUSd48NrRnSX6Pi47piXg3MwXgKBeQ');
    print('AUTHORITY ${sender.pubkey.toBase58()}');
    final AddressLookupTableAccount? account = await connection.getAddressLookupTable(address);
  });

  test('error', () async {
    try {
      final Keypair newSender = Keypair.generateSync();
      final blockhash = await connection.getLatestBlockhash();
      final TransactionInstruction txIx = await _transferIx();
      final Transaction tx = Transaction.v0(
        payer: newSender.pubkey,
        recentBlockhash: blockhash.blockhash,
        instructions: [txIx],
      );
      tx.sign([newSender]);
      final sig = await connection.sendTransaction(tx);
      print('ERROR SIG $sig');
      final t = await connection.getTransaction(sig);
    } catch (error) {
      print('TX ERROR $error');
    }
  });

  test('deserialize', () async {
    const encoded = '6GhS2ZJhrEfHXU1X5xsiY2jkTMVjEMw1NwZmrgvySH7QhRKGseCSuNJd8sPfrQxbUV4JEMUU2c9nEV'
        'hVK45kTYmA4HXLt8qk4qGQwv7aocVepYR8ewj1Wj1k4NpZrGZTdRRXARxf1Cp6BgtjZvSymnfij1h91kgRfKEwutHGzn'
        'z7F7DTQKGRGtT3oFfqawecVKJesy2x98ZPu1ts';
    Message.fromBase58(encoded);
  });
}
