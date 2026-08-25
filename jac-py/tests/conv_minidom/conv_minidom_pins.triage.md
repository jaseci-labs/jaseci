# Triage report: `conv_minidom_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_minidom.py
- guest leg: 0/126 marks
- pins: **113 passed** / 126 run (+5 quarantined of 131 extracted)

| pin | result | got |
|---|---|---|
| MinidomTest.testDocumentAsyncAttr | PASS | |
| MinidomTest.testParseFromBinaryFile | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testParseFromTextFile | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testAttrModeSetsParamsAsAttrs | PASS | |
| MinidomTest.testAttrModeSetsNonOptionalAttrs | PASS | |
| MinidomTest.testGetElementsByTagName | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testInsertBefore | PASS | |
| MinidomTest.testInsertBeforeFragment | PASS | |
| MinidomTest.testAppendChild | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testSetAttributeNodeWithoutOwnerDocument | PASS | |
| MinidomTest.testAppendChildFragment | PASS | |
| MinidomTest.testReplaceChildFragment | PASS | |
| MinidomTest.testLegalChildren | PASS | |
| MinidomTest.testNamedNodeMapSetItem | PASS | |
| MinidomTest.testNonZero | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testUnlink | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testContext | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testElement | PASS | |
| MinidomTest.testAAA | PASS | |
| MinidomTest.testAAB | PASS | |
| MinidomTest.testAddAttr | PASS | |
| MinidomTest.testDeleteAttr | PASS | |
| MinidomTest.testRemoveAttr | PASS | |
| MinidomTest.testRemoveAttrNS | PASS | |
| MinidomTest.testRemoveAttributeNode | PASS | |
| MinidomTest.testHasAttribute | PASS | |
| MinidomTest.testChangeAttr | PASS | |
| MinidomTest.testGetAttribute | PASS | |
| MinidomTest.testGetAttributeNS | PASS | |
| MinidomTest.testGetAttributeNode | PASS | |
| MinidomTest.testGetElementsByTagNameNS | PASS | |
| MinidomTest.testGetEmptyNodeListFromElementsByTagNameNS | PASS | |
| MinidomTest.testElementReprAndStr | PASS | |
| MinidomTest.testElementReprAndStrUnicode | PASS | |
| MinidomTest.testElementReprAndStrUnicodeNS | PASS | |
| MinidomTest.testAttributeRepr | PASS | |
| MinidomTest.testWriteXML | PASS | |
| MinidomTest.test_toxml_quote_text | PASS | |
| MinidomTest.test_toxml_quote_attrib | PASS | |
| MinidomTest.testAltNewline | PASS | |
| MinidomTest.test_toprettyxml_with_text_nodes | PASS | |
| MinidomTest.test_toprettyxml_with_adjacent_text_nodes | PASS | |
| MinidomTest.test_toprettyxml_preserves_content_of_text_node | PASS | |
| MinidomTest.testProcessingInstruction | PASS | |
| MinidomTest.testProcessingInstructionRepr | PASS | |
| MinidomTest.testWriteText | PASS | |
| MinidomTest.testDocumentElement | PASS | |
| MinidomTest.testTooManyDocumentElements | PASS | |
| MinidomTest.testCreateElementNS | PASS | |
| MinidomTest.testCreateAttributeNS | PASS | |
| MinidomTest.testParse | PASS | |
| MinidomTest.testParseString | PASS | |
| MinidomTest.testComment | PASS | |
| MinidomTest.testAttrListItem | PASS | |
| MinidomTest.testAttrListItems | PASS | |
| MinidomTest.testAttrListItemNS | PASS | |
| MinidomTest.testAttrListKeys | PASS | |
| MinidomTest.testAttrListKeysNS | PASS | |
| MinidomTest.testRemoveNamedItem | PASS | |
| MinidomTest.testRemoveNamedItemNS | PASS | |
| MinidomTest.testAttrListValues | PASS | |
| MinidomTest.testAttrListLength | PASS | |
| MinidomTest.testAttrList__getitem__ | PASS | |
| MinidomTest.testAttrList__setitem__ | PASS | |
| MinidomTest.testSetAttrValueandNodeValue | PASS | |
| MinidomTest.testParseElement | PASS | |
| MinidomTest.testParseAttributes | PASS | |
| MinidomTest.testParseElementNamespaces | PASS | |
| MinidomTest.testParseAttributeNamespaces | PASS | |
| MinidomTest.testParseProcessingInstructions | PASS | |
| MinidomTest.testChildNodes | PASS | |
| MinidomTest.testFirstChild | PASS | |
| MinidomTest.testHasChildNodes | PASS | |
| MinidomTest.testCloneElementShallow | PASS | |
| MinidomTest.testCloneElementDeep | PASS | |
| MinidomTest.testCloneDocumentShallow | PASS | |
| MinidomTest.testCloneDocumentDeep | PASS | |
| MinidomTest.testCloneDocumentTypeDeepOk | PASS | |
| MinidomTest.testCloneDocumentTypeDeepNotOk | PASS | |
| MinidomTest.testCloneDocumentTypeShallowOk | PASS | |
| MinidomTest.testCloneDocumentTypeShallowNotOk | PASS | |
| MinidomTest.testImportDocumentShallow | PASS | |
| MinidomTest.testImportDocumentDeep | PASS | |
| MinidomTest.testImportDocumentTypeShallow | PASS | |
| MinidomTest.testImportDocumentTypeDeep | PASS | |
| MinidomTest.testCloneAttributeShallow | PASS | |
| MinidomTest.testCloneAttributeDeep | PASS | |
| MinidomTest.testClonePIShallow | PASS | |
| MinidomTest.testClonePIDeep | PASS | |
| MinidomTest.testCloneNodeEntity | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'swap_attr'"> |
| MinidomTest.testNormalize | PASS | |
| MinidomTest.testNormalizeCombineAndNextSibling | PASS | |
| MinidomTest.testNormalizeDeleteWithPrevSibling | PASS | |
| MinidomTest.testNormalizeDeleteWithNextSibling | PASS | |
| MinidomTest.testNormalizeDeleteWithTwoNonTextSiblings | PASS | |
| MinidomTest.testNormalizeDeleteAndCombine | PASS | |
| MinidomTest.testNormalizeRecursion | PASS | |
| MinidomTest.testBug0777884 | PASS | |
| MinidomTest.testBug1433694 | PASS | |
| MinidomTest.testSiblings | PASS | |
| MinidomTest.testParents | PASS | |
| MinidomTest.testNodeListItem | PASS | |
| MinidomTest.testEncodings | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'"> |
| MinidomTest.testStandalone | PASS | |
| MinidomTest.testRenameAttribute | PASS | |
| MinidomTest.testRenameElement | PASS | |
| MinidomTest.testRenameOther | PASS | |
| MinidomTest.testWholeText | PASS | |
| MinidomTest.testPatch1094164 | PASS | |
| MinidomTest.testReplaceWholeText | PASS | |
| MinidomTest.testSchemaType | PASS | |
| MinidomTest.testSetIdAttribute | PASS | |
| MinidomTest.testSetIdAttributeNS | PASS | |
| MinidomTest.testSetIdAttributeNode | PASS | |
| MinidomTest.testPickledDocument | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC PicklingError "Can\'t pickle <class \'ceval.Document\'>: it\'s not found as ceval.Document"'> |
| MinidomTest.testDeepcopiedDocument | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| MinidomTest.testSerializeCommentNodeWithDoubleHyphen | PASS | |
| MinidomTest.testEmptyXMLNSValue | PASS | |
| MinidomTest.testExceptionOnSpacesInXMLNSValue | PASS | |
| MinidomTest.testDocRemoveChild | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.testProcessingInstructionNameError | GUEST-WRONG-OUTPUT | RUN<'AttributeError: findfile'> |
| MinidomTest.test_minidom_attribute_order | PASS | |
| MinidomTest.test_toxml_with_attributes_ordered | PASS | |
| MinidomTest.test_toprettyxml_with_attributes_ordered | PASS | |
| MinidomTest.test_toprettyxml_with_cdata | PASS | |
| MinidomTest.test_cdata_parsing | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| MinidomTest.testAppendChildNoQuadraticComplexity | decorator:support.requires_resource |
| MinidomTest.testGetAttrList | self.addCleanup |
| MinidomTest.testGetAttrValues | self.addCleanup |
| MinidomTest.testTextRepr | self.addCleanup |
| MinidomTest.testUserData | uses-self.UserDataHandler |

## Expected vs got

### MinidomTest.testAppendChild (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testCloneNodeEntity (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'swap_attr'">

### MinidomTest.testContext (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testDeepcopiedDocument (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### MinidomTest.testDocRemoveChild (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testEncodings (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC LookupError 'unknown encoding: utf-16'">

### MinidomTest.testGetElementsByTagName (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testNonZero (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testParseFromBinaryFile (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testParseFromTextFile (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testPickledDocument (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC PicklingError "Can\'t pickle <class \'ceval.Document\'>: it\'s not found as ceval.Document"'>

### MinidomTest.testProcessingInstructionNameError (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>

### MinidomTest.testUnlink (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: findfile'>
