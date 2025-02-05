# Playground

This an interactive playground for `nodeadm`'s config parser packaged in the
browser via WebAssembly!

You can test out the validity of your EC2 Userdata and see any of the potential
errors that might happen at runtime.

<div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/ace.min.js" integrity="sha512-NIDAOLuPuewIzUrGoK5fXxowwGDm0DFJhI5TJPyTP6MeY2hUcCSKJr54fecQTEZ8kxxEO2NBrILQSUl4qZ37FA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="/amazon-eks-ami/assets/javascripts/wasm_exec.js"></script>
    <body>
        <div style="display: grid; margin: auto;">
            <div id="editor" style="height:50vh"></div>
            <textarea readonly style="height:15vh" id="response"></textarea>
        </div>
    </body>
    <script>
        const editor = ace.edit("editor", {
            useWorker: false,
            theme: "ace/theme/monokai",
            mode: "ace/mode/yaml",
            showPrintMargin: false,
        });

        // a global hook established ahead of time with the target WASM binary
        function wasmLoadedHook() {
            editor.session.on("change", function(_) {
                document.getElementById("response").textContent = nodeadmCheck(editor.session.getValue())
            });
            editor.session.setValue(`
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
    cidr: 10.100.0.0/16
  kubelet:
    config:
      shutdownGracePeriod: 30s
      featureGates:
        DisableKubeletCloudCredentialProviders: true

--BOUNDARY--`.trim());
        }

        const go = new Go();
        WebAssembly.instantiateStreaming(fetch("/amazon-eks-ami/assets/wasm/nodeadm.wasm"), go.importObject).then((result) => {
            go.run(result.instance);
        });
    </script>
</div>
