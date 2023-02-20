import {
    createSpyRPCServiceClient,
    subscribeSignedVAA,
  } from "@certusone/wormhole-spydk";
  
  function parseVaa(signedVaa) {
      var sigStart = 6;
      var numSigners = signedVaa[5];
      var sigLength = 66;
      var guardianSignatures = [];
      for (var i = 0; i < numSigners; ++i) {
          var start = i * sigLength + 1;
          guardianSignatures.push({
              r: signedVaa.subarray(start, start + 32),
              s: signedVaa.subarray(start + 32, start + 64),
              v: signedVaa[start + 64],
          });
      }
      var body = signedVaa.subarray(sigStart + sigLength * numSigners);
      return {
          version: signedVaa[0],
          guardianSignatures: guardianSignatures,
          timestamp: body.readUInt32BE(0),
          nonce: body.readUInt32BE(4),
          emitterChain: body.readUInt16BE(8),
          emitterAddress: body.subarray(10, 42),
          sequence: body.readBigUInt64BE(42),
          consistencyLevel: body[50],
          sender: body.subarray(51, 73),
          amount: body.readBigUInt256BE(73)
      };
  }
  
  var liquidity_change = {
      2: 0, //Goerli
      5: 0 //Mumbai
  }
  
  const client = createSpyRPCServiceClient("localhost:7073"); // default port
  const stream = await subscribeSignedVAA(client, {});
  stream.on("data", ({ vaaBytes }) => {
  
      var parsedVAA = parseVaa(Buffer.from(vaaBytes, 'base64'))
      
      //Update liquidity values 
      liquidity_change[parsedVAA.emitterChain] = liquidity_change[parsedVAA.emitterChain] + parsedVAA.amount;
      console.log(parsedVAA.emitterChain);
  
  });