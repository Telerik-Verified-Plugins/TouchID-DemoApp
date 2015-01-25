(function (global) {
    var DemoViewModel,
        app = global.app = global.app || {};

    DemoViewModel = kendo.data.ObservableObject.extend({

        checkAvailability: function () {
          if (!this.checkSimulator()) {
            window.plugins.touchid.isAvailable(
              // success callback
              function(msg) {
                alert('Yes, TouchID is available');
              },

              // error callback
              function(msg) {
                alert('No, TouchID is not available. Details: ' + JSON.stringify(msg));
              }
            )
          }
        },

        authenticateWithPasscodeFallback: function () {
          if (!this.checkSimulator()) {
            window.plugins.touchid.verifyFingerprint(
              // The prompt shown in the fingerprint window
              'Scan your fingerprint to access your account',

              // success callback
              function(msg) {
                alert('Verification success!');
              },

              // error callback
              function(msg) {
                alert('Verification error: ' + JSON.stringify(msg));
              }
            )
          }
        },

        authenticateWithCustomPasswordFallback: function () {
          if (!this.checkSimulator()) {
            window.plugins.touchid.verifyFingerprintWithCustomPasswordFallback (
              // The prompt shown in the fingerprint window
              'Scan your fingerprint to log in',

              // success callback
              function(msg) {
                alert('Verification success!');
              },

              // error callback
              function(msg) {
                if (msg.code == -2) {
                  alert('User canceled');
                } else if (msg.code == -3) {
                  alert('User picked fallback, so we should now offer an alternative login mechanism');
                } else {
                  alert('Verification error: ' + JSON.stringify(msg));
                }
              }
            )
          }
        },

        checkSimulator: function() {
            if (window.navigator.simulator === true) {
                alert('This plugin is not available in the simulator.');
                return true;
            } else if (window.plugins === undefined || window.plugins.touchid === undefined) {
                alert('Plugin not found. Maybe you are running in AppBuilder Companion app which currently does not support this plugin.');
                return true;
            } else {
                return false;
            }
        }        
    });

    app.demoService = {
        viewModel: new DemoViewModel()
    };
})(window);