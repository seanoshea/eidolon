import Quick
import Nimble
import Kiosk
import Moya
import ReactiveCocoa
import Nimble_Snapshots

class LoadingViewControllerTests: QuickSpec {
    override func spec() {
        var subject: LoadingViewController!

        beforeEach {
            subject = testLoadingViewController()
            subject.animate = false
        }

        describe("default") {

            it("placing a bid") {
                subject.placingBid = true
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.completes = false
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("registering a user") {
                subject.placingBid = false
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.completes = false
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }
        }

        describe("errors") {

            it("correctly placing a bid") {
                subject.placingBid = true
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.errors = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("correctly registering a user") {
                subject.placingBid = false
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.errors = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }
        }

        describe("ending") {

            it("placing bid success highest") {
                subject.placingBid = true
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.bidIsResolved = true
                stubViewModel.isHighestBidder = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("placing bid success not highest") {
                subject.placingBid = true
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.bidIsResolved = true
                stubViewModel.isHighestBidder = false
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("placing bid not resolved") {
                subject.placingBid = true
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.bidIsResolved = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("registering user success") {
                subject.placingBid = false
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.createdNewBidder = true
                stubViewModel.bidIsResolved = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }

            it("registering user not resolved") {
                subject.placingBid = false
                let fulfillmentController = StubFulfillmentController()
                let stubViewModel = StubLoadingViewModel(bidNetworkModel: BidderNetworkModel(fulfillmentController: fulfillmentController), placingBid: subject.placingBid)
                stubViewModel.bidIsResolved = true
                subject.viewModel = stubViewModel

                expect(subject).to(haveValidSnapshot())
            }
        }
    }
}

let loadingViewControllerTestImage = UIImage.testImage(named: "artwork", ofType: "jpg")

func testLoadingViewController() -> LoadingViewController {
    let controller = UIStoryboard.fulfillment().viewControllerWithID(.LoadingBidsorRegistering).wrapInFulfillmentNav() as! LoadingViewController
    return controller
}

public class StubLoadingViewModel: LoadingViewModel {
    var errors = false
    var completes = true

    public override func performActions() -> RACSignal {
        if completes {
            if errors {
                return RACSignal.error(NSError(domain: "", code: 0, userInfo: nil))
            } else {
                return RACSignal.empty()
            }
        } else {
            return RACSignal.never()
        }
    }
}

public class StubFulfillmentController: FulfillmentController {
    public lazy var bidDetails: BidDetails = { () -> BidDetails in
        let bidDetails = BidDetails.stubbedBidDetails()
        bidDetails.setImage = { (_, imageView) -> () in
            imageView.image = loadingViewControllerTestImage
        }
        return bidDetails
    }()

    public var auctionID: String! = ""
    public var xAccessToken: String?
    public var loggedInProvider: ReactiveMoyaProvider<ArtsyAPI>? = Provider.StubbingProvider()
    public var loggedInOrDefaultProvider: ReactiveMoyaProvider<ArtsyAPI> = Provider.StubbingProvider()
}
