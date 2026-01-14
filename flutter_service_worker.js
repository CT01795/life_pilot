'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"manifest.json": "ed12eb72b40452ab20830fb2fc649972",
"index.html": "5fe209ff7a13fb0cffb7cef7a7555930",
"/": "5fe209ff7a13fb0cffb7cef7a7555930",
"assets/blockly/index.html": "f775dfd1d31ed81bc7b8ab627e93764c",
"assets/blockly/blockly_compressed.js": "91b86ffca1735da33b289594f0e5d759",
"assets/blockly/msg/js/zh-hant.js": "33ea34aa45e5a87f01c9bb879452fd80",
"assets/blockly/javascript_compressed.js": "faff45afbfcf4d8b95a501f81fd9bb4f",
"assets/blockly/blocks_compressed.js": "3e55b2fd165638573822ea8fbeba8563",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "a8648ead636d52d5ad4b6f1cb9a9ec2d",
"assets/assets/blockly/index.html": "f775dfd1d31ed81bc7b8ab627e93764c",
"assets/assets/blockly/blockly_compressed.js": "91b86ffca1735da33b289594f0e5d759",
"assets/assets/blockly/msg/js/zh-hant.js": "33ea34aa45e5a87f01c9bb879452fd80",
"assets/assets/blockly/javascript_compressed.js": "faff45afbfcf4d8b95a501f81fd9bb4f",
"assets/assets/blockly/blocks_compressed.js": "3e55b2fd165638573822ea8fbeba8563",
"assets/assets/weather_icons/09d.png": "e85e9228da07e2d04e79c6138c6424aa",
"assets/assets/weather_icons/13d.png": "999e2b5d67490237e26f787e39586120",
"assets/assets/weather_icons/04n.png": "533a26f80a181eedfdc8dc0ad3add84f",
"assets/assets/weather_icons/04d.png": "533a26f80a181eedfdc8dc0ad3add84f",
"assets/assets/weather_icons/01n.png": "6693bdf685ae981975be5fa266250456",
"assets/assets/weather_icons/03d.png": "8621a91e65ff543f9bb77fbb1848ddf6",
"assets/assets/weather_icons/10n.png": "105df06468669236b0f877652280c6a4",
"assets/assets/weather_icons/50d.png": "cab19004c5beaec9a7a730695414ebb4",
"assets/assets/weather_icons/02n.png": "36be1cbcb95a119365e00862ecb303d7",
"assets/assets/weather_icons/50n.png": "cab19004c5beaec9a7a730695414ebb4",
"assets/assets/weather_icons/11n.png": "aa590aa0cb8aec05ec6a8c0153f23b50",
"assets/assets/weather_icons/01d.png": "ed22e08c4aafb6ac3afa98e002abd5a3",
"assets/assets/weather_icons/11d.png": "aa590aa0cb8aec05ec6a8c0153f23b50",
"assets/assets/weather_icons/09n.png": "e85e9228da07e2d04e79c6138c6424aa",
"assets/assets/weather_icons/03n.png": "8621a91e65ff543f9bb77fbb1848ddf6",
"assets/assets/weather_icons/13n.png": "999e2b5d67490237e26f787e39586120",
"assets/assets/weather_icons/10d.png": "126cd52cc45cc4071de18dc074e127ad",
"assets/assets/weather_icons/02d.png": "85bacbaf387366adc4b0ca81b4c7cdca",
"assets/assets/maps/kinmen.png": "b3658e0d0d59cf742517a285409e3475",
"assets/assets/maps/central_america.png": "d0213a11693d2988c998abff6244dd43",
"assets/assets/maps/center_asia.png": "ccd2a24177167ba3dbb2083b1c5e0723",
"assets/assets/maps/asia.png": "55f4c3028797d2329a70b26bac88ab1b",
"assets/assets/maps/taiwan.png": "91cbb9a2284beb4e3684ce8655c8c053",
"assets/assets/maps/jianada.png": "f9ac5d800823fb8c4b37e2ad1305929b",
"assets/assets/maps/north_america.png": "f42df6d63b484af0983b95e8cd16efe5",
"assets/assets/maps/malaysia.png": "e65e6e1e26955642d75abdf6480ede06",
"assets/assets/maps/penghu.png": "2309cd1cbbfed15ae30d4b7c85ad83a5",
"assets/assets/maps/vietnam.png": "fd9bab76eaf2ee7825f0b9a64eee885a",
"assets/assets/maps/south_america.png": "673ad0c7ffdf4ecbfcd9c60b852ac05a",
"assets/assets/maps/japan.png": "792837976f2f3c080a459c7ae23cdd26",
"assets/assets/maps/arctic.png": "52c695e50f9252436b630c8ed12b95cd",
"assets/assets/maps/africa.png": "1aa533fe4fef1d4f7b9aa15705105c81",
"assets/assets/maps/south_asia.png": "8d68317bc059a5a9b128579fdb9de621",
"assets/assets/maps/australia.png": "c6a7b17f7f18e51e1ae31f29c1ac4aa1",
"assets/assets/maps/china.png": "53104ab999a02cbd8d4be6cf3e780b3d",
"assets/assets/maps/japan_1.png": "80e833866d70b6a6f55ec3fb832fadd5",
"assets/assets/maps/east_asia.png": "0a02746a629bfa01c82c021939c7c23b",
"assets/assets/maps/france.png": "f050e597634e9f9900295901443a9756",
"assets/assets/maps/philippines.png": "34a955b1981b1371e37a9335775ae49d",
"assets/assets/maps/antarctica.png": "e5430af1f73e08c36f6d1906e953b9a8",
"assets/assets/maps/lienchiang.png": "75942448c9223aa02d38b4217a6be77b",
"assets/assets/maps/little_ryukyu.png": "6c74dfc87d42b08e559b394bf76f3ce2",
"assets/assets/maps/oceania.png": "568ec09c665f833638f14a245e57a255",
"assets/assets/maps/thailand.png": "4839372a84d430849e69dcf7ffb2cd4b",
"assets/assets/maps/singapore.png": "c33778cc15be584110eda65b405ace98",
"assets/assets/maps/world.png": "155b33c60493c523b45d1b67536eb0a0",
"assets/assets/maps/greenland.png": "0bc7c26bf24fac64dcc095739997b24b",
"assets/assets/maps/taiwan_outlying_islands.png": "07857cec60a71e5b7c323990becf1fec",
"assets/assets/maps/korea.png": "0baf9d40ddce2ea79f7bc1a6c3f9aad6",
"assets/assets/maps/europ.png": "474ec390b4e4d50e717a39742705fa9c",
"assets/assets/maps/southeast_asia.png": "1ea8a6bcdfb448aec6a746829a76a366",
"assets/assets/maps/kansai.png": "61200044fa261b41b9b61a278731fdd8",
"assets/assets/maps/lanyu.png": "5fb56493c663a42d52f274326d0232ac",
"assets/assets/maps/europe_1.png": "d8630d0372c2c81ceed23036b181be74",
"assets/assets/maps/america.png": "a7697a2a37e1c5888dab5eeeee943967",
"assets/assets/maps/central_europ.png": "35410cb48f45b5bb7e76e522ce6ac29b",
"assets/assets/maps/new_zealand.png": "7f0bfcbed4bdc6acab4e6521939c1e59",
"assets/assets/maps/okinawa.png": "b34b95a6182b4061d53705dbd9a2bacf",
"assets/fonts/MaterialIcons-Regular.otf": "82c45633ec8a398068fb715fe491489b",
"assets/NOTICES": "6af2b84c56e8dc70b744982b3019ebdb",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin": "aa75e22d27cf2352fe0f21c495ac2698",
"assets/AssetManifest.json": "3c786b215ddfe0c85fbacdd94856875a",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter_bootstrap.js": "3af60139be77babf19ff9339b599a1cd",
"version.json": "3d24f8e1c43390d4ffe74cc3fce20e2a",
"main.dart.js": "4bed925af1be9075d7b2b98828698b72"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
