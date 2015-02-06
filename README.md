# Pledges

[![Build Status](https://travis-ci.org/robertfmurdock/Pledges.svg?branch=master)](https://travis-ci.org/robertfmurdock/Pledges)

A simple promise implementation for Swift.

Feedback and pull requests welcome.

This library includes a few things I adore about the promise pattern:

- Easy functionality for converting a Pledge of one type into another type... with full Swift type safety!
- The ability to take a group of Pledges of **different** types and convert it to a single Pledge of **one tuple** with all the type information intact!
- No forced unpacking! One of the most lovely things about Swift is that it embraces nil analysis with both arms. Pledges will never ask you to "safely" unpack an optional type. Death to the null pointer exception!
- That said, Pledges is fully compatible with returning a nil value as a success if you like! eg. Pledge<String?>() You decide what your Pledge should return.

So you say you want documentation? ;-) I'm working to make the [unit tests](PledgesTests/PledgesTest.swift) into highly readable examples. If you have any questions, ask! I can use those to make sure new examples are added that make things clearer.
