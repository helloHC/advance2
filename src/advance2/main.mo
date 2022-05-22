import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import TrieSet "mo:base/TrieSet";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import List "mo:base/List";

import IC "./ic";

import Types "./types";

actor class () = self {
    stable var foundationSet : TrieSet.Set<Principal> = TrieSet.empty<Principal>();
    stable var canisterSet : TrieSet.Set<Principal> = TrieSet.empty<Principal>();
    stable var proposals : Trie.Trie<Nat, Types.Proposal> = Trie.empty<Nat, Types.Proposal>();
    stable var proposalsID : Nat = 0;
    stable var threshold : Nat = 0;

    func isMember(user: Principal) : Bool {
        TrieSet.mem(foundationSet, user, Principal.hash(user), Principal.equal)
    };

    func hasCanister(canister: Principal) : Bool {
        TrieSet.mem(canisterSet, canister, Principal.hash(canister), Principal.equal)
    };

    func hasDone(num: Nat) : Bool {
        if(num >= threshold) {
            true
        } else {
            false
        }
    };

    //添加提案
    public shared ({ caller }) func suggest(operation: Types.Operations, canisterID: ?Principal, wasmCode: ?Nat8) : async () {
        assert(isMember(caller));
        var _approvers: List.List<Principal> = List.nil();
        _approvers := List.push(caller, _approvers);
        proposalsID += 1;
        proposals := Trie.put(proposals, { hash = Hash.hash(proposalsID); key = proposalsID}, Nat.equal, {
            proposer = caller;
            wasmCode = wasmCode;
            operation = operation;
            canisterID = canisterID;
            approvers = _approvers;
            done = false;
        }).0;
    };

    //表决提案
    public shared ({ caller }) func poll(proposalsID: Nat) : async () {
        switch (Trie.get(proposals, { hash = Hash.hash(proposalsID); key = proposalsID }, Nat.equal)) {
            case(?_proposal) {
                let _proposal_ = List.push(caller, _proposal.approvers);
                let suggestion = {
                    proposer = _proposal.proposer;
                    wasmCode = _proposal.wasmCode;
                    operation = _proposal.operation;
                    canisterID = _proposal.canisterID;
                    approvers = _proposal_;
                    done = hasDone(List.size(_proposal_));
                };
                proposals := Trie.replace(proposals, { hash = Hash.hash(proposalsID); key = proposalsID }, Nat.equal, ?suggestion).0;
                if(hasDone(List.size(_proposal_))) {
                    await operate(suggestion);
                }
            };
            case(_) {
                
            };
        };
    };

    //执行提案
    func operate(proposal: Types.Proposal) : async () {
        let ic : IC.Self = actor("aaaa-aa");
        switch(proposal.operation) {
            case (#create) {
                let canister_settings = {
                    freezing_threshold = null;
                    controllers = ?[Principal.fromActor(self)];
                    memory_allocation = null;
                    compute_allocation = null;
                };
                let result = await ic.create_canister({ settings = ?canister_settings });
                canisterSet := TrieSet.put(canisterSet, result.canister_id, Principal.hash(result.canister_id), Principal.equal);
            };
            case (#install) {
                await ic.install_code({
                    arg = [];
                    wasm_module = [Option.unwrap(proposal.wasmCode)];
                    mode = #install;
                    canister_id = Option.unwrap(proposal.canisterID);
                });
            };
            case (#start) {
                await ic.start_canister({
                    canister_id = Option.unwrap(proposal.canisterID);
                });
            };
            case (#stop) {
                await ic.stop_canister({
                    canister_id = Option.unwrap(proposal.canisterID);
                });
            };
            case (#delete) {
                await ic.delete_canister({
                    canister_id = Option.unwrap(proposal.canisterID);
                });
            };
        };
    };

    public shared func updateFoundationMember(members: [Principal]) : async () {
        for(member in Iter.fromArray(members)) {
            foundationSet := TrieSet.put(foundationSet, member, Principal.hash(member), Principal.equal);
        }
    };

    public shared func initial(members: [Principal], _threshold: Nat) : async () {
        assert(TrieSet.size(foundationSet) == 0 and _threshold <= members.size());

        for(member in Iter.fromArray(members)) {
            foundationSet := TrieSet.put(foundationSet, member, Principal.hash(member), Principal.equal);
        };

        threshold := _threshold;
    };
};