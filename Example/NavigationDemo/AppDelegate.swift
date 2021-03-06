import UIKit
import Marshroute

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate
{
    var window: UIWindow?
    
    // Auxiliary window to show touch marker (even over `UIPopoverController`).
    // It should be created lazily, because `UIKit` works incorrenctly
    // if you create two `UIWindow`s at `application(_:didFinishLaunchingWithOptions:)`
    private lazy var touchCursorDrawingWindow: UIWindow? = {
        let window = UIWindow(frame: UIScreen.main.bounds)
        
        window.isUserInteractionEnabled = false
        window.windowLevel = UIWindow.Level.statusBar
        window.backgroundColor = .clear
        window.isHidden = false
        window.rootViewController = self.window?.rootViewController
        
        return window
    }()
    
    private var touchCursorDrawer: TouchCursorDrawerImpl?
    
    private var touchCursorDrawingWindowProvider: (() -> (UIWindow?)) {
        return { [weak self] in
            return self?.touchCursorDrawingWindow
        }
    }
    
    private var touchEventObserver: TouchEventObserver?

    private var rootTransitionsHandler: ContainingTransitionsHandler?
    
    private var rootTransitionsHandlerProvider: (() -> (ContainingTransitionsHandler?)) {
        return { [weak self] in
            return self?.rootTransitionsHandler
        }
    }
    
    // MARK: - UIApplicationDelegate
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // Init `Marshroute` stack
        MarshroutePrintManager.setUpPrintPlugin(DemoPrintPlugin())
        MarshrouteAssertionManager.setUpAssertionPlugin(DemoAssertionPlugin())
        let marshrouteSetupService = MarshrouteSetupServiceImpl()
        
        let applicationModuleSeed = ApplicationModuleSeedProvider().applicationModuleSeed(
            marshrouteSetupService: marshrouteSetupService
        )
        
        // Init service factory
        let serviceFactory = ServiceFactoryImpl(
            topViewControllerFinder: applicationModuleSeed.marshrouteStack.topViewControllerFinder,
            rootTransitionsHandlerProvider: rootTransitionsHandlerProvider,
            transitionsMarker: applicationModuleSeed.marshrouteStack.transitionsMarker,
            transitionsTracker: applicationModuleSeed.marshrouteStack.transitionsTracker,
            transitionsCoordinatorDelegateHolder: applicationModuleSeed.marshrouteStack.transitionsCoordinatorDelegateHolder
        )
        
        // Init assemly factory
        let assemblyFactory = AssemblyFactoryImpl(
            serviceFactory: serviceFactory,
            marshrouteStack: applicationModuleSeed.marshrouteStack
        )
        
        let applicationModule: ApplicationModule
            
        if UIDevice.current.userInterfaceIdiom == .pad {
            applicationModule = assemblyFactory.applicationAssembly().ipadModule(moduleSeed: applicationModuleSeed)
        } else {
            applicationModule = assemblyFactory.applicationAssembly().module(moduleSeed: applicationModuleSeed)
        }
        
        rootTransitionsHandler = applicationModule.transitionsHandler
        
        // Main application window, which shares delivered touch events with its `touchEventForwarder`
        let touchEventSharingWindow = TouchEventSharingWindow(frame: UIScreen.main.bounds)
        touchEventSharingWindow.rootViewController = applicationModule.viewController
        touchEventSharingWindow.touchEventForwarder = serviceFactory.touchEventForwarder()
        
        // Object for drawing temporary red markers in places where user touches the screen
        let touchCursorDrawer = TouchCursorDrawerImpl(windowProvider: touchCursorDrawingWindowProvider)
        self.touchCursorDrawer = touchCursorDrawer
        
        let touchEventObserver = serviceFactory.touchEventObserver()
        touchEventObserver.addListener(touchCursorDrawer)
        self.touchEventObserver = touchEventObserver
        
        window = touchEventSharingWindow
        window?.makeKeyAndVisible()
        
        subscribeOnPeekAndPopStateChanges(
            observable: applicationModuleSeed.marshrouteStack.peekAndPopStateObservable
        )

        return true
    }
    
    private func subscribeOnPeekAndPopStateChanges(observable: PeekAndPopStateObservable) {
        observable.addObserver(
            disposable: self,
            onPeekAndPopStateChange: { viewController, peekAndPopState in
                debugPrint("viewController: \(viewController) changed `peek and pop` state: \(peekAndPopState)")
            }
        )
    }
}
