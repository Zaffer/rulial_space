# Rulial Space

A 3D game in space where you take on hypergraph rewriting missions.

## Roadmap
- [x] Serverless P2P multiplayer over WebRTC via token exchange signaling  
- [ ] Hypergraph rewriting mechanics
- [ ] Mission system
- [ ] Time-based scoring  
- [ ] Player vs player combat
- [ ] Advanced weaponry  

========================================================

# for co-pilot 👇
- keep it simple
- minimal possible code
- prefer declarative style
- ask permission before major changes
- ask questions if unsure how to proceed
- explain what you are thinking, but avoid long summaries of what changed
- don't assume I am right, read the code and refer to web documentation if stuck


## Current Status
✅ **WebRTC Multiplayer**: Client/server topology with manual token-based signaling (no dedicated server)  
✅ **3D Physics Simulation**: Interactive nodes and edges with forces and collision  
✅ **Player Controls**: FPS-style camera movement with mouse capture/release  
✅ **UI System**: Multiplayer menu with hosting/client role management  

## Architecture
- **Main Scene**: Generates random hypergraph (nodes + edges) in 3D space
- **Multiplayer**: WebRTC peer-to-peer with server relay for automatic peer discovery
- **Physics**: RigidBody nodes with spring-like edge connections
- **Player**: Camera with laser pointer and projectile shooting
- **Remote Players**: Visual representations of connected peers

## Key Files
- `main.gd` - Core scene setup, hypergraph generation, multiplayer integration
- `multiplayer/multiplayer_manager_mesh.gd` - WebRTC networking (client/server with relay)
- `multiplayer/multiplayer_menu.gd` - UI for connection management
- `node.gd` - Physics nodes with attraction/repulsion forces
- `edge.gd` - Visual connections between nodes
- `camera.gd` - FPS controls with laser and projectile systems



## Technical Notes
- **WebRTC Setup**: Server (ID=1) hosts, clients (ID>1) connect through server relay
- **Token Exchange**: Manual copy/paste signaling for WebRTC handshake
- **Physics**: Uses Godot's RigidBody3D with custom force application
- **Multiplayer**: Built on Godot's MultiplayerAPI with WebRTCMultiplayerPeer
