import Foundation
import NetworkExtension
import WireGuardKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var adapter: WireGuardAdapter?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard
            let providerConfiguration = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
            let wgQuickConfig = providerConfiguration["WgQuickConfig"] as? String
        else {
            completionHandler(PacketTunnelError.invalidConfiguration)
            return
        }

        do {
            let configuration = try TunnelConfiguration(
                fromWgQuickConfig: wgQuickConfig,
                called: "FreeRoute"
            )
            let newAdapter = WireGuardAdapter(with: self) { _, message in
                NSLog("FreeRoute tunnel: %@", message)
            }
            adapter = newAdapter
            newAdapter.start(tunnelConfiguration: configuration) { error in
                completionHandler(error)
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        guard let adapter else {
            completionHandler()
            return
        }
        adapter.stop { error in
            if let error {
                NSLog("FreeRoute tunnel stop failed: %@", error.localizedDescription)
            }
            completionHandler()
        }
        self.adapter = nil
    }
}

private enum PacketTunnelError: LocalizedError {
    case invalidConfiguration

    var errorDescription: String? {
        "Не найдена конфигурация WireGuard для VPN-туннеля."
    }
}
