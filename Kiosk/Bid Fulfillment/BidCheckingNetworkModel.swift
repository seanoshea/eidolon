import UIKit
import ReactiveCocoa
import Moya

public class BidCheckingNetworkModel: NSObject {

    private var pollInterval = NSTimeInterval(1)
    private var maxPollRequests = 6
    private var pollRequests = 0

    // inputs
    public let fulfillmentController: FulfillmentController

    // outputs
    public dynamic var bidIsResolved = false
    public dynamic var isHighestBidder = false
    public dynamic var reserveNotMet = false

    private var mostRecentSaleArtwork:SaleArtwork?

    public init(fulfillmentController: FulfillmentController) {
        self.fulfillmentController = fulfillmentController
    }

    public func waitForBidResolution () -> RACSignal {
        return self.pollForUpdatedSaleArtwork().then { [weak self] (_) in
            return self == nil ? RACSignal.empty() : self!.checkForMaxBid()

        } .doNext { _ in
            self.bidIsResolved = true
            return

        // If polling fails, we can still show bid confirmation. Do not error.
        } .catchTo( RACSignal.empty() )
    }

    private func pollForUpdatedSaleArtwork() -> RACSignal {

        let beginningBidCents = fulfillmentController.bidDetails.saleArtwork?.saleHighestBid?.amountCents ?? 0

        let updatedSaleArtworkSignal = getUpdatedSaleArtwork().flattenMap { [weak self] (saleObject) -> RACStream! in
            self?.pollRequests++

            logger.log("Polling \(self?.pollRequests) of \(self?.maxPollRequests) for updated sale artwork")

            let saleArtwork = saleObject as? SaleArtwork
            let updatedBidCents = saleArtwork?.saleHighestBid?.amountCents ?? 0

            // TODO: handle the case where the user was already the highest bidder
            if  updatedBidCents != beginningBidCents {

                // This is an updated model – hooray!
                if let saleArtwork = saleArtwork {
                    self?.mostRecentSaleArtwork = saleArtwork
                    self?.fulfillmentController.bidDetails.saleArtwork?.updateWithValues(saleArtwork)
                    self?.reserveNotMet = ReserveStatus.initOrDefault(saleArtwork.reserveStatus).reserveNotMet
                }

                return RACSignal.empty()

            } else {

                if (self?.pollRequests ?? 0) >= (self?.maxPollRequests ?? 0) {
                    // We have exceeded our max number of polls, fail.
                    return RACSignal.error(nil)

                } else {

                    // We didn't get an updated value, so let's try again.
                    return RACSignal.empty().delay(self?.pollInterval ?? 1).then({ () -> RACSignal! in
                        return self?.pollForUpdatedSaleArtwork()
                    })
                }
            }
        }

        return RACSignal.empty().delay(pollInterval).then { updatedSaleArtworkSignal }
    }

    private func checkForMaxBid() -> RACSignal {
        return self.getMyBidderPositions().doNext { [weak self] (newBidderPositions) -> Void in
            let newBidderPositions = newBidderPositions as? [BidderPosition]
            if let topBidID = self?.mostRecentSaleArtwork?.saleHighestBid?.id {
                for position in newBidderPositions! {
                    if position.highestBid?.id == topBidID {
                        self?.isHighestBidder = true
                    }
                }
            } else {
                RACSignal.error(nil)
            }
        }
    }


    private func getMyBidderPositions() -> RACSignal {
        let artworkID = fulfillmentController.bidDetails.saleArtwork!.artwork.id;
        let auctionID = fulfillmentController.bidDetails.saleArtwork!.auctionID!

        let endpoint: ArtsyAPI = ArtsyAPI.MyBidPositionsForAuctionArtwork(auctionID: auctionID, artworkID: artworkID)
        return fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().mapToObjectArray(BidderPosition.self)
    }

    private func getUpdatedSaleArtwork() -> RACSignal {

        let artworkID = fulfillmentController.bidDetails.saleArtwork!.artwork.id;
        let auctionID = fulfillmentController.bidDetails.saleArtwork!.auctionID!

        let endpoint: ArtsyAPI = ArtsyAPI.AuctionInfoForArtwork(auctionID: auctionID, artworkID: artworkID)
        return fulfillmentController.loggedInProvider!.request(endpoint).filterSuccessfulStatusCodes().mapJSON().mapToObject(SaleArtwork.self)
    }
}
