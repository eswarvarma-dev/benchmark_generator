library benchmark_generator.ng2_ts_generator;

import 'package:benchmark_generator/generator.dart';

class Ng2TypeScriptGenerator implements Generator {
  final _fs = new VFileSystem();
  AppGenSpec _genSpec;

  VFileSystem generate(AppGenSpec genSpec) {
    _genSpec = genSpec;
    _generatePackageJson();
    _generateIndexHtml();
    _generateIndexTs();
    _genSpec.components.values.forEach(_generateComponentFiles);
    return _fs;
  }

  _addFile(String path, String contents) {
    _fs.addFile(path, contents);
  }

  _generatePackageJson() {
    _addFile('package.json', '''
    {
      "name": "${_genSpec.name}",
      "version": "0.0.0",
      "dependencies": {
        "angular2": "2.0.0-alpha.46",
        "systemjs": "0.19.2"
      },
      "devDependencies": {
        "live-server": "^0.8.1",
        "typescript": "^1.6.2"
      }
    }''');
  }

  void _generateIndexHtml() {
    _addFile('src/index.html', '''
<!doctype html>
<html>
  <head>
    <title>Generated app: ${_genSpec.name}</title>
    <script src="https://code.angularjs.org/tools/system.js"></script>
    <script src="https://code.angularjs.org/tools/typescript.js"></script>
    <script src="https://code.angularjs.org/2.0.0-alpha.46/angular2.min.js"></script>
    <script>
      System.config({
        transpiler: 'typescript',
        typescriptOptions: { emitDecoratorMetadata: true }
      });
      System.import('./index.ts');
    </script>
  </head>
  <body>
    <${_genSpec.rootComponent.name}>
      Loading...
    </${_genSpec.rootComponent.name}>
  </body>
</html>
''');
  }

  void _generateIndexTs() {
    _addFile('src/index.ts', '''
import {bootstrap} from 'angular2/angular2';
import {${_genSpec.rootComponent.name}} from '${_genSpec.name}/${_genSpec.rootComponent.name}';

window.console.timeStamp('>>> before bootstrap');
bootstrap(${_genSpec.rootComponent.name}).then((_) {
  window.console.timeStamp('>>> after bootstrap');
});
''');
  }

  void _generateComponentFiles(ComponentGenSpec compSpec) {
    _generateComponentCodeFile(compSpec);
    _generateComponentTemplateFile(compSpec);
  }

  void _generateComponentCodeFile(ComponentGenSpec compSpec) {
    final directiveImports = <String>[];
    final directives = <String>[];
    int totalProps = 0;
    int totalTextProps = 0;
    compSpec.template
      .map((NodeInstanceGenSpec nodeSpec) {
        totalProps += nodeSpec.propertyBindingCount;
        totalTextProps += nodeSpec.textBindingCount;
        return nodeSpec;
      })
      .where((NodeInstanceGenSpec nodeSpec) => nodeSpec.ref is ComponentGenSpec)
      .forEach((NodeInstanceGenSpec nodeSpec) {
        final childComponent = nodeSpec.nodeName;
        directives.add(childComponent);
        directiveImports.add("import {${childComponent}} from '${childComponent}';\n");
      });

    final props = new StringBuffer('\n');
    props.write(new List.generate(totalProps, (i) => '  var prop${i};')
        .join('\n'));

    final textProps = new StringBuffer('\n');
    textProps.write(new List.generate(totalTextProps, (i) => '  var text${i};')
        .join('\n'));

    final branchProps = new StringBuffer();
    int i = 0;
    compSpec.template.forEach((NodeInstanceGenSpec nodeSpec) {
      if (nodeSpec.branchSpec != null) {
        branchProps.write('  var branch${i++};');
      }
    });

    _addFile('src/app/${compSpec.name}.ts', '''
import {Component, View} from 'angular2/angular2';
${directiveImports.join('')}
@Component({
  selector: '${compSpec.name}'
})
@View({
  templateUrl: '${compSpec.name}.html'
${directives.isNotEmpty ? '  , directives: ${directives}' : ''}
})
export class ${compSpec.name} {
${props}
${branchProps}
${textProps}
}
''');
  }

  void _generateComponentTemplateFile(ComponentGenSpec compSpec) {
    int branchIndex = 0;
    int propIdx = 0;
    int textIdx = 0;
    var template = compSpec.template.map((NodeInstanceGenSpec nodeSpec) {
      final bindings = new StringBuffer();
      if (nodeSpec.propertyBindingCount > 0) {
        bindings.write(' ');
        bindings.write(new List.generate(nodeSpec.propertyBindingCount, (i) => '[prop${i}]="prop${i}"')
            .join(' '));
      }
      final branch = new StringBuffer();
      if (nodeSpec.branchSpec is IfBranchSpec) {
        IfBranchSpec ifBranch = nodeSpec.branchSpec;
        branch.write(' *ng-if="branch${branchIndex++}"');
      } else if (nodeSpec.branchSpec is RepeatBranchSpec) {
        RepeatBranchSpec repeatBranch = nodeSpec.branchSpec;
        branch.write(' *ng-for="#item of branch${branchIndex++}"');
      }

      final textBindings = new List.generate(nodeSpec.textBindingCount, (_) {
        return '{{text${textIdx++}}}';
      }).join();

      return '<${nodeSpec.nodeName}${bindings}${branch}>${textBindings}</${nodeSpec.nodeName}>';
    }).join('\n');
    _addFile('src/app/${compSpec.name}.html', template);
  }
}
