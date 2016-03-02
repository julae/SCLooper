// For life performance to redundantize my loop pedal. Because it is heavy.
//
// working principle:
//     individual buffers for loops
//     helper Synths for recording to /  playing from buffer
//     recording function which records to buffer and rythmically chops up input



s.makeGui;
// global buffer variables

(
~loop1 = Buffer.alloc(s, 44100 * 8.0, 2);
~loop2 = Buffer.alloc(s, 44100 * 16.0, 2);
)


//synths
(
// record synths
SynthDef(\recBuf,{ arg out = 0, bufnum = 0, offset = 0;
	var in;
	in = AudioIn.ar([1, 2]);
	RecordBuf.ar(in, bufnum, offset: offset, preLevel: 1);
}).load(s);


SynthDef(\playBuf,{
	arg out = 0, bufnum;
	var signal;
	signal = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);
	Out.ar(out, signal);
}).add;

// kazoo synth (from help file, I plan to add own Synths using the Pitch UGen)
SynthDef("pitchFollow1",{
    var in, amp, freq, hasFreq, out;
    in = Mix.new(SoundIn.ar([0,1]));
    amp = Amplitude.kr(in, 0.05, 0.05);
    # freq, hasFreq = Pitch.kr(in, ampThreshold: 0.02, median: 7);
    //freq = Lag.kr(freq.cpsmidi.round(1).midicps, 0.05);
    out = Mix.new(VarSaw.ar(freq * [0.5,1,2], 0, LFNoise1.kr(0.3,0.1,0.1), amp));
    6.do({
        out = AllpassN.ar(out, 0.040, [0.040.rand,0.040.rand], 2)
    });
    Out.ar(0,out)
}).add;

// audio in

SynthDef(\AudioIn, {
	arg out = 0;

	Out.ar(out,
		AudioIn.ar(1)
	)
}).add;
)



// chopped recording to buffer
(
~recorder = {

// different buffer for multiple loops
arg buffer;
var numPieces, duration, offset, record, bufferLength, routine;

	bufferLength = buffer.numFrames;

	//amount of sound snippets
	numPieces = [4, 6, 8, 12, 16, 32].choose;
	("numPieces:" + numPieces).postln;

	//duration of each sound snippet and break inbetween
	duration = (0.5 * bufferLength / numPieces).floor;

	routine = Routine{
		for (0, numPieces, {
			arg i;
			offset = i * 2 * duration;
			record = Synth(\recBuf, [\out, 0, \bufnum, buffer.bufnum, \offset, offset]);
			"start".postln;
			(duration/44100).wait;
			record.run(false);
			"stop".postln;
	});
	"record finished".postln;
	}.play

};
)

// play buffer; start before recording, start all at once

~loop1Play = Synth(\playBuf, [\bufnum, ~loop1.bufnum, \out, 0]);
~loop2Play = Synth(\playBuf, [\bufnum, ~loop2.bufnum]);


// loop control
~loop1Play.run(false);
~loop1Play.run(true);


~loop2Play.run(false);
~loop2Play.run(true);

~loop1Play.free;
~loop2Play.free;

// record loops
~recorder.value(~loop1);
~recorder.value(~loop2);

// free buffer
~loop1.free;
~loop2.free;

~kazoo = Synth(\pitchFollow1);
~kazoo.free;

~audioIn = Synth(\AudioIn);
~audioIn.free;

//recording to file
s.recChannels = 2;
s.recSampleFormat = 'int24';
s.recHeaderFormat = 'wav';
s.prepareForRecord;

s.record;
s.stopRecording;


