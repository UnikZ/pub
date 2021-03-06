// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS d.file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../descriptor.dart' as d;
import '../test_pub.dart';
import '../serve/utils.dart';

const AGGREGATE_TRANSFORMER = """
import 'dart:async';

import 'package:barback/barback.dart';
import 'package:path/path.dart' as p;

class ManyToOneTransformer extends AggregateTransformer
    implements LazyAggregateTransformer {
  ManyToOneTransformer.asPlugin();

  String classifyPrimary(AssetId id) {
    if (id.extension != '.txt') return null;
    return p.url.dirname(id.path);
  }

  Future apply(AggregateTransform transform) {
    return transform.primaryInputs.toList().then((assets) {
      assets.sort((asset1, asset2) => asset1.id.path.compareTo(asset2.id.path));
      return Future.wait(assets.map((asset) => asset.readAsString()));
    }).then((contents) {
      var id = new AssetId(transform.package,
          p.url.join(transform.key, 'out.txt'));
      transform.addOutput(new Asset.fromString(id, contents.join('\\n')));
    });
  }

  void declareOutputs(DeclaringAggregateTransform transform) {
    transform.declareOutput(new AssetId(transform.package,
        p.url.join(transform.key, 'out.txt')));
  }
}
""";

main() {
  integration("loads a lazy aggregate transformer", () {
    serveBarback();

    d.dir(appPath, [
      d.pubspec({
        "name": "myapp",
        "transformers": ["myapp"],
        "dependencies": {"barback": "any"}
      }),
      d.dir("lib", [
        d.file("transformer.dart", AGGREGATE_TRANSFORMER),
      ]),
      d.dir("web", [d.file("foo.txt", "foo"), d.file("bar.txt", "bar")])
    ]).create();

    pubGet();
    var server = pubServe();
    // The transformer should preserve laziness.
    server.stdout.expect("Build completed successfully");

    requestShouldSucceed("out.txt", "bar\nfoo");
    endPubServe();
  });
}
