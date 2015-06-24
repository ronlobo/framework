import 'package:testcase/testcase.dart';
export 'package:testcase/init.dart';
import 'package:bridge/view.dart';
import 'package:bridge/http.dart';
import 'package:rikulo_el/el.dart';

class BtlParserTest implements TestCase {
  BtlParser parser;
  Router router;

  setUp() {
    router = new Router();
    parser = new BtlParser(new UrlGenerator(router));
  }

  tearDown() {
  }

  @test
  it_does_nothing_to_plain_html() {
    expect(parser.parse('<div></div>'), equals('<div></div>'));
  }

  @test
  it_can_inject_a_variable() {
    expect(parser.parse(r'<div>$var</div>', {'var': 'value'}),
    equals('<div>value</div>'));
  }

  @test
  it_throws_when_data_does_not_cover_all_variables() {
    expect(() => parser.parse(r'<div>$var</div>'), throwsA(const isInstanceOf<PropertyNotFoundException>()));
  }

  @test
  it_can_inject_variable_nested_in_map() {
    expect(parser.parse(r'<div>${map.key}</div>', {
      'map': {
        'key': 'value'
      }
    }), equals('<div>value</div>'));
  }

  @test
  it_can_repeat_markup_for_every_item_in_list() {
    expect(parser.parse(r"<for in=$items>$key</for>", {
      'items': [
        {'key': 'value'},
        {'key': 'value2'},
      ]
    }), equals('valuevalue2'));
  }

  @test
  it_can_name_the_repeated_list_item() {
    expect(parser.parse(r"<for each=$item in=$items>${item.key}</for>", {
      'items': [
        {'key': 'value'},
        {'key': 'value2'},
      ]
    }), equals('valuevalue2'));
  }

  @test
  it_can_escape_a_variable_character() {
    expect(parser.parse(r'\$var'), equals(r'$var'));
  }

  @test
  it_has_if_statements() {
    expect(parser.parse(r'<if $show>shown</if>', {'show': true}), equals('shown'));
    expect(parser.parse(r'<if $show>shown</if>', {'show': false}), equals(''));
  }

  @test
  it_can_have_nested_if_statements() {
    expect(parser.parse(r'<if $show><if $show2>shown</if></if>', {
      'show': true,
      'show2': true,
    }), equals('shown'));
    expect(parser.parse(r'<if $show><if $show2>shown</if></if>', {
      'show': false,
      'show2': true,
    }), equals(''));
    expect(parser.parse(r'<if $show><if $show2>shown</if></if>', {
      'show': true,
      'show2': false,
    }), equals(''));
  }

  @test
  it_can_use_multiple_functions() {
    var btl = r'''
<div>
<if $showTitle><h1>$title</h1></if>
<for each=$item in=$items>
  \$wag
  <if ${item.show}>
    // Insert content
    <p>${item.content}</p>
  </if>
</for>
</div>
    '''.trim();

    expect(parser.parse(btl, {
      'showTitle': true,
      'title': 'Title',
      'items': [
        {'show': true, 'content': 'Content1'},
        {'show': true, 'content': 'Content2'},
        {'show': false, 'content': 'Content3'},
      ]
    }).replaceAll(new RegExp(r'\s+'), ' '), equals(
        r'<div> <h1>Title</h1> $wag <p>Content1</p> $wag <p>Content2</p> $wag </div>'
    ));
  }

  @test
  it_can_have_comments() {
    expect(parser.parse('Text// Comment'), equals('Text'));
  }

  @test
  it_knows_when_two_slashes_are_not_a_comment() {
    expect(parser.parse('<a href="//notacomment"></a>'), equals('<a href="//notacomment"></a>'));
  }

  @test
  it_can_simulate_form_methods() {
    var before = "<form method='put'></form>";
    var after = "<form method='POST'><input type='hidden' name='_method' value='PUT'></form>";
    expect(parser.parse(before), equals(after));
  }

  @test
  it_can_use_route_names_for_form_actions() {
    router.get('/', () => '', name: 'home');
    var before = "<form route='home'>";
    var after = "<form action='/'>";
    expect(parser.parse(before), equals(after));
  }

  @test
  it_can_access_object_fields_as_nested_variables() {
    var template = r'<div>${test.property}</div>';
    expect(parser.parse(template, {'test': new TestClass()}), equals('<div>value</div>'));
  }

  @test
  it_allows_for_complex_expressions_within_bracketed_variables() {
    var template = r'''
    ${(1 + 1) * 2 / intVar}
    ${boolVar ? 'string' : stringVar}
    ${stringVar == 'stringValue' ? 123 : 1234}
    ${stringVar == 'otherValue'}
    ${2 * (1 + 1)}
    ''';

    var intVar = 4, boolVar = true, stringVar = 'stringValue';
    var resultOne = r'''
    1
    string
    123
    false
    4
    ''';
    expect(parser.parse(template, {
      'intVar': intVar,
      'boolVar': boolVar,
      'stringVar': stringVar
    }), equals(resultOne));

    intVar = 1;
    boolVar = false;
    stringVar = 'otherValue';
    var resultTwo = r'''
    4
    otherValue
    1234
    true
    4
    ''';
    expect(parser.parse(template, {
      'intVar': intVar,
      'boolVar': boolVar,
      'stringVar': stringVar
    }), equals(resultTwo));
  }

  @test
  it_can_have_global_functions_in_expression() {
    expect(parser.parse(r'${globalFunction("value")}'), equals('value plus'));
  }
}

globalFunction(String message) {
  return '$message plus';
}

class TestClass {
  String property = 'value';
}
