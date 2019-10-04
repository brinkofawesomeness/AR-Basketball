//
//  ViewController.swift
//  AR-Basketball
//
//  Created by Conner Brinkley on 10/3/19.
//  Copyright © 2019 brinkofawesomeness. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var shootBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        //sceneView.showsStatistics = true
        
        // Prevents screen from being dimmed
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Transform the button
        shootBtn.layer.cornerRadius = shootBtn.frame.width / 2
        
        // Add some gravity
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -3.0, 0)
        
        // Recognize when the plane was tapped
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable vertical plane detection
        configuration.planeDetection = .vertical
        
        // Show feature points
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // Recognize that a user tapped the plane
    @objc func didTap(_ gesture: UITapGestureRecognizer) {
        
        switch gesture.state {
        case .ended:
            let location = gesture.location(ofTouch: 0, in: sceneView)
            let hit = sceneView.hitTest(location, types: .existingPlaneUsingGeometry)
            if let hit = hit.first {
                placeGoal(hit)
            }
        default:
            print("Hit default")
        }
    }
    
    // Create the object to be placed on the plane
    func placeGoal(_ hit: ARHitTestResult) {
        let basket = SCNNode()
        let backboard = createBackboard()
        let hoop = createHoop()
        
        basket.addChildNode(backboard)
        basket.addChildNode(hoop)
        
        backboardPosition(node: backboard, atHit: hit)
        hoopPosition(node: hoop, atHit: hit)
        
        sceneView.scene.rootNode.addChildNode(basket)
    }
    
    // Creates the backboard
    private func createBackboard() -> SCNNode {
        let box = SCNBox(width: 0.6, height: 0.4, length: 0.02, chamferRadius: 0.02)
        let boxNode = SCNNode(geometry: box)
        let material = SCNMaterial()
        
        material.diffuse.contents = UIImage(named: "art.scnassets/backboard.jpg")
        box.materials = [material]
        boxNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
        
        return boxNode
    }
    
    // Creates the hoop
    private func createHoop() -> SCNNode {
        let hoop = SCNTorus(ringRadius: 0.2, pipeRadius: 0.01)
        let hoopNode = SCNNode(geometry: hoop)
        let material = SCNMaterial()
        
        material.diffuse.contents = UIColor .red
        hoop.materials = [material]
        let shapeOptions = [ SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron ]
        hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: hoop, options: shapeOptions))
        
        return hoopNode
    }
    
    // Calculate position of the backboard
    private func backboardPosition(node: SCNNode, atHit hit: ARHitTestResult) {
        node.transform = SCNMatrix4(hit.anchor!.transform)
        node.eulerAngles = SCNVector3Make(node.eulerAngles.x + (Float.pi / 2), node.eulerAngles.y, node.eulerAngles.z)
        
        let position = SCNVector3Make(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
        
        node.position = position
    }
    
    // Calculate the position of the hoop
    private func hoopPosition(node: SCNNode, atHit hit: ARHitTestResult) {
        node.transform = SCNMatrix4(hit.anchor!.transform)
        node.eulerAngles = SCNVector3Make(node.eulerAngles.x + (Float.pi / 2), node.eulerAngles.y, node.eulerAngles.z)
        
        let position = SCNVector3Make(hit.worldTransform.columns.3.x,
                                      hit.worldTransform.columns.3.y,
                                      hit.worldTransform.columns.3.z)

        node.position = position
    }
    
    // Tells the app what to do when we tap 'Shoot'
    @IBAction func shootBall(_ sender: Any) {
        let camera = sceneView.session.currentFrame!.camera
        let ball = Ball()
        
        // transform to location of camera
        var translation = matrix_float4x4(ball.transform)
        translation.columns.3.z = -0.1
        translation.columns.3.x = 0.03
        ball.simdTransform = matrix_multiply(camera.transform, translation)
        
        let force = simd_make_float4(-1.75, 0, -2.25, 0)
        let rotatedForce = simd_mul(camera.transform, force)
        let impulse = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)

        sceneView?.scene.rootNode.addChildNode(ball)
        ball.launch(inDirection: impulse)
    }
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
           
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            plane.firstMaterial?.diffuse.contents = UIColor(white: 1, alpha: 0.75)

            let planeNode = SCNNode(geometry: plane)
            planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.x, planeAnchor.center.z)
            planeNode.eulerAngles.x = -.pi / 2
            
            node.addChildNode(planeNode)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane {
            
            plane.width = CGFloat(planeAnchor.extent.x)
            plane.height = CGFloat(planeAnchor.extent.z)
            planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        }
    }
}

class Ball: SCNNode {
    
    override init() {
        super.init()
        
        let sphere = SCNSphere(radius: 0.1)
        let material = SCNMaterial()
        
        material.diffuse.contents = UIImage(named: "art.scnassets/ballTexture.png")
        sphere.materials = [material]
        geometry = sphere
        eulerAngles = SCNVector3(CGFloat.pi / 2, (CGFloat.pi * 0.25), 0)
        
        physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        physicsBody?.restitution = 0.75
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch(inDirection direction: SCNVector3) {
        physicsBody?.applyForce(direction, asImpulse: true)
    }
}
