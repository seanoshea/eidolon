import Foundation
import ReactiveCocoa
import Moya

public class BidderNetworkModel: NSObject {
    public dynamic var createdNewBidder = false

    // MARK: - Getters

    public var fulfillmentController: FulfillmentController

    public init(fulfillmentController: FulfillmentController) {
        self.fulfillmentController = fulfillmentController
    }

    // MARK: - Main Signal

    public func createOrGetBidder() -> RACSignal {
        return createOrUpdateUser().then {
            self.createOrUpdateBidder()

        }.then {
            self.getMyPaddleNumber()
        }
    }

    // MARK: - Chained Signals

    private func checkUserEmailExists(email: String) -> RACSignal {
        let request = Provider.sharedProvider.request(.FindExistingEmailRegistration(email: email))

        return request.map { [weak self] (response) -> NSNumber in
            let moyaResponse = response as! MoyaResponse
            return moyaResponse.statusCode != 404
        }
    }

    private func createOrUpdateUser() -> RACSignal {
        let boolSignal = self.checkUserEmailExists(fulfillmentController.bidDetails.newUser.email!)
        let signal = RACSignal.`if`(boolSignal, then: self.updateUser(), `else`: self.createNewUser())
        return signal.then { self.addCardToUser() }
    }

    private func createNewUser() -> RACSignal {
        let newUser = fulfillmentController.bidDetails.newUser
        let endpoint: ArtsyAPI = ArtsyAPI.CreateUser(email: newUser.email!, password: newUser.password!, phone: newUser.phoneNumber!, postCode: newUser.zipCode!, name: newUser.name ?? "")

        return Provider.sharedProvider.request(endpoint).filterSuccessfulStatusCodes().doError { (error) in
            logger.log("Creating user failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")

        }.then {
            self.updateProvider()
        }
    }

    private func updateProviderIfNecessary() -> RACSignal {
        let loggedInProviderSignalIsNil = RACSignal.`return`(fulfillmentController.loggedInProvider == nil)

        return RACSignal.`if`(loggedInProviderSignalIsNil, then: updateProvider(), `else`: RACSignal.empty())
    }

    private func updateUser() -> RACSignal {
        let newUser = fulfillmentController.bidDetails.newUser
        let endpoint: ArtsyAPI = ArtsyAPI.UpdateMe(email: newUser.email!, phone: newUser.phoneNumber!, postCode: newUser.zipCode!, name: newUser.name ?? "")

        return updateProviderIfNecessary().then {
            self.fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON()
        }.doError { (error) in
            logger.log("Updating user failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    private func addCardToUser() -> RACSignal {
        if (fulfillmentController.bidDetails.newUser.creditCardToken == nil) { return RACSignal.empty() }
        let endpoint: ArtsyAPI = ArtsyAPI.RegisterCard(stripeToken: fulfillmentController.bidDetails.newUser.creditCardToken!)

        // on Staging the card tokenization fails

        return fulfillmentController.loggedInProvider!.request(endpoint).doError { (error) in
            logger.log("Adding Card to User failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    // MARK: - Auction / Bidder Signals

    private func createOrUpdateBidder() -> RACSignal {
        let boolSignal = self.checkForBidderOnAuction(self.fulfillmentController.auctionID)
        let trueSignal = RACSignal.empty()
        let falseSignal = self.registerToAuction().then { self.generateAPIN() }
        return RACSignal.`if`(boolSignal, then: trueSignal, `else`: falseSignal)
    }

    private func checkForBidderOnAuction(auctionID: String) -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.MyBiddersForAuction(auctionID: auctionID)
        let request = fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().mapToObjectArray(Bidder.self)

        return request.map { [weak self] (bidders) -> NSNumber in
            let bidders = bidders as! [Bidder]
            if let bidder = bidders.first {
                self?.fulfillmentController.bidDetails.bidderID = bidder.id
                self?.fulfillmentController.bidDetails.bidderPIN =  bidder.pin
                return true
            }
            return false

        }.doError { (error) in
            logger.log("Getting user bidders failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    private func registerToAuction() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.RegisterToBid(auctionID: fulfillmentController.auctionID)
        let signal = fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().mapToObject(Bidder.self)

        return signal.doNext{ [weak self] (bidder) in
            if let bidder = bidder as? Bidder {
                self?.fulfillmentController.bidDetails.bidderID = bidder.id
                self?.createdNewBidder = true
            }

        }.doError { (error) in
            logger.log("Registering for Auction Failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    private func generateAPIN() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.CreatePINForBidder(bidderID: fulfillmentController.bidDetails.bidderID!)

        return fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().doNext { [weak self](json) -> Void in

            let pin = json["pin"] as? String
            self?.fulfillmentController.bidDetails.bidderPIN = pin

        }.doError { (error) in
            logger.log("Generating a PIN for bidder has failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    private func getMyPaddleNumber() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.Me
        return fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().mapToObject(User.self).doNext { [weak self] (user) -> Void in

            self?.fulfillmentController.bidDetails.paddleNumber =  (user as! User).paddleNumber
            return

        }.doError { (error) in
            logger.log("Getting Bidder ID failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }

    private func updateProvider() -> RACSignal {
        let endpoint: ArtsyAPI = ArtsyAPI.XAuth(email: fulfillmentController.bidDetails.newUser.email!, password: fulfillmentController.bidDetails.newUser.password!)

        return fulfillmentController.loggedInOrDefaultProvider.request(endpoint).filterSuccessfulStatusCodes().mapJSON().doNext { [weak self] (accessTokenDict) -> Void in

            if let accessToken = accessTokenDict["access_token"] as? String {
                self?.fulfillmentController.xAccessToken = accessToken
            }

        } .doError { (error) in
            logger.log("Getting Access Token failed.")
            logger.log("Error: \(error.localizedDescription). \n \(error.artsyServerError())")
        }
    }
}
