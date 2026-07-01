type QuoteTracking record {|
    string txnId;
    string quoteId?;
    string status;
    map<json> agentStates;
|};

type ClaimTracking record {|
    string claimId;
    string txnId;
    string status;
    map<json> agentStates;
|};

type UpdateClaimDescriptionRequest record {|
    string claimId;
    string claimDescription;
|};