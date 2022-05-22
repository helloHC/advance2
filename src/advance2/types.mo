module {
  public type Operations = {
    #create;
    #install;
    #start;
    #stop;
    #delete;
  };

  public type Proposal = {
		proposer: Principal;
		wasmCode:  ?Nat8;
		operation: Operations;
		canisterID:  ?Principal;
		approvers: [Principal];
		done: Bool;
	};
}