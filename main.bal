import ballerina/http;
import ballerinax/mongodb;

// MongoDB connection settings as configurables
configurable string mongoDbUrl = ?;
final string databaseName = "WSO2_InsuranceAccelerator";

// Initialize the MongoDB client
final mongodb:Client mongoClient = check new ({
    connection: mongoDbUrl
});

// Create a single HTTP listener for the tracking service on port 8291
listener http:Listener trackingListener = new http:Listener(8291);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowHeaders: ["Content-Type", "Authorization", "Accept", "Origin"],
        allowMethods: ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"]
    }
}

service /track on trackingListener {

    isolated resource function put claims/updateDescription(@http:Payload UpdateClaimDescriptionRequest req) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("Claims");

        map<json> filter = {"claimRequest.claimId": req.claimId};
        mongodb:Update update = {
            set: {
                "claimRequest.claimDescription": req.claimDescription
            }
        };

        mongodb:UpdateResult updateResult = check coll->updateOne(filter, update);
        if updateResult.matchedCount == 0 {
            return error("Claim not found. claimId: " + req.claimId);
        }
    }

    isolated resource function post claims/tracking(@http:Payload ClaimTracking req) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("ClaimsTracking");
        
        map<json> filter = {"claimId": req.claimId};
        map<json> trackingDoc = {
            "claimId": req.claimId,
            "txnId": req.txnId,
            "status": req.status,
            "agentStates": req.agentStates
        };
        mongodb:Update update = {
            set: trackingDoc
        };
        
        mongodb:UpdateOptions options = { upsert: true };
        _ = check coll->updateOne(filter, update, options);
    }
    
    isolated resource function post claims/tracking/[string claimId]/agent/[string agentName](@http:Payload map<json> agentData) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("ClaimsTracking");
        
        map<json> filter = {"claimId": claimId};
        map<json> setOp = {};
        setOp["agentStates." + agentName] = agentData;
        
        mongodb:Update update = {
            set: setOp
        };
        
        mongodb:UpdateOptions options = { upsert: true };
        _ = check coll->updateOne(filter, update, options);
    }
    
    isolated resource function get claims/tracking/[string claimId]() returns json|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("ClaimsTracking");
        
        map<json> filter = {"claimId": claimId};
        stream<record {}, error?> result = check coll->find(filter);
        
        record {|record {} value;|}|error? doc = result.next();
        if doc is record {|record {} value;|} {
            return doc.value.toJson();
        }
        return error("Tracking not found for claimId: " + claimId);
    }

    isolated resource function get claims/tracking_pending() returns json[]|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("ClaimsTracking");
        
        map<json> filter = {"status": "PENDING_HUMAN_REVIEW"};
        stream<record {}, error?> result = check coll->find(filter);
        
        json[] pendingClaims = [];
        record {|record {} value;|}|error? doc = result.next();
        while doc is record {|record {} value;|} {
            pendingClaims.push(doc.value.toJson());
            doc = result.next();
        }
        return pendingClaims;
    }
    
    isolated resource function get claims/tracking_all() returns json[]|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("ClaimsTracking");
        
        map<json> filter = {};
        stream<record {}, error?> result = check coll->find(filter);
        
        json[] allClaims = [];
        record {|record {} value;|}|error? doc = result.next();
        while doc is record {|record {} value;|} {
            allClaims.push(doc.value.toJson());
            doc = result.next();
        }
        return allClaims;
    }

    isolated resource function post quotes/tracking(@http:Payload QuoteTracking req) returns http:Response|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {"txnId": req.txnId};
        map<json> trackingDoc = {
            "txnId": req.txnId,
            "status": req.status,
            "agentStates": req.agentStates
        };
        mongodb:Update update = {
            set: trackingDoc
        };
        
        mongodb:UpdateOptions options = { upsert: true };
        _ = check coll->updateOne(filter, update, options);
        
        http:Response resp = new;
        resp.statusCode = 200;
        resp.setJsonPayload({"status": "Success"});
        return resp;
    }
    
    isolated resource function post quotes/tracking/[string txnId]/agent/[string agentName](@http:Payload map<json> agentData) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {"txnId": txnId};
        
        map<json> setOp = {};
        setOp["agentStates." + agentName] = agentData;
        
        mongodb:Update update = {
            set: setOp
        };
        
        mongodb:UpdateOptions options = { upsert: true };
        _ = check coll->updateOne(filter, update, options);
    }
    
    isolated resource function get quotes/tracking/[string txnId]() returns json|http:Response|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {"txnId": txnId};
        stream<record {}, error?> result = check coll->find(filter);
        
        record {|record {} value;|}|error? doc = result.next();
        if doc is record {|record {} value;|} {
            return doc.value.toJson();
        }
        http:Response notFound = new;
        notFound.statusCode = 404;
        notFound.setJsonPayload({"error": "Tracking not found for txnId: " + txnId});
        return notFound;
    }

    isolated resource function get quotes/tracking/quote/[string quoteId]() returns json|http:Response|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {"quoteId": quoteId};
        stream<record {}, error?> result = check coll->find(filter);
        
        record {|record {} value;|}|error? doc = result.next();
        if doc is record {|record {} value;|} {
            return doc.value.toJson();
        }
        http:Response notFound = new;
        notFound.statusCode = 404;
        notFound.setJsonPayload({"error": "Tracking not found for quoteId: " + quoteId});
        return notFound;
    }

    isolated resource function get quotes/tracking_pending() returns json[]|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {"status": "PENDING_HUMAN_REVIEW"};
        stream<record {}, error?> result = check coll->find(filter);
        
        json[] pendingQuotes = [];
        record {|record {} value;|}|error? doc = result.next();
        while doc is record {|record {} value;|} {
            pendingQuotes.push(doc.value.toJson());
            doc = result.next();
        }
        return pendingQuotes;
    }
    
    isolated resource function get quotes/tracking_all() returns json[]|error {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        map<json> filter = {};
        stream<record {}, error?> result = check coll->find(filter);
        
        json[] allQuotes = [];
        record {|record {} value;|}|error? doc = result.next();
        while doc is record {|record {} value;|} {
            allQuotes.push(doc.value.toJson());
            doc = result.next();
        }
        return allQuotes;
    }

    isolated resource function patch quotes/tracking/[string txnId]/status(@http:Payload map<json> body) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        string newStatus = check body["status"].ensureType();
        mongodb:Update update = {
            set: {
                "status": newStatus
            }
        };
        
        _ = check coll->updateOne({"txnId": txnId}, update);
    }

    isolated resource function patch quotes/tracking/[string txnId]/quoteId(@http:Payload map<json> body) returns error? {
        mongodb:Database db = check mongoClient->getDatabase(databaseName);
        mongodb:Collection coll = check db->getCollection("QuotesTracking");
        
        string quoteId = check body["quoteId"].ensureType();
        mongodb:Update update = {
            set: {
                "quoteId": quoteId
            }
        };
        
        _ = check coll->updateOne({"txnId": txnId}, update);
    }
}
