// For life performances to redundantize my loop pedal. Because it is heavy.
//
//
//     helper Synths for recording to /  playing from buffer
//     effect Synths
//     recording function which records to buffer and chops up input
//     pitch following Synth


//s.options.device_("US-600 (Core Audio)");

s.boot;
s.makeGui;



//synths
(
// record synths
SynthDef(\recBuf,{
	arg out = 0, bufnum = 0, offset = 0, duration = 1;
	var in, envelope;
	envelope = EnvGen.ar(Env.asr(0.05, 1, duration/2 - 0.05), doneAction: 2);
	in = SoundIn.ar([0, 1]) * envelope;
	RecordBuf.ar(in, bufnum, offset: offset, preLevel: 1, doneAction: 2);
}).load(s);


SynthDef(\playBuf,{
	arg out = 0, bufnum;
	var signal;
	signal = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);
	Out.ar(out, signal);
}).add;


// kazoo synth, effect bus default: 20
SynthDef(\pitchCake,{
	arg out, bus, wet = 0, ampMul = 10;
    var in, amp, sound, effect, freq, hasFreq;
	in = SoundIn.ar([0, 1]);
    amp = Amplitude.kr(in, 0.05, 0.05, 0.5);
    # freq, hasFreq = Pitch.kr(in, ampThreshold: 0.02, median: 7);
	sound = Mix.new(LFSaw.ar([0.333, 0.5] * freq) + LFPulse.ar([0.333, 0.5] * freq) * amp * ampMul);
	effect = HPF.ar(LinPan2.ar(LPF.ar(sound, SinOsc.kr(0.5, 0, 100, 400), SinOsc.kr(1, 0, 1))), 50);
	Out.ar(out, effect * (1 - wet));
	Out.ar(bus, effect * wet);
}).add;


// audio in, effect bus default: 22
SynthDef(\AudioIn, {
	arg out = 0, bus = 22, wet = 0.5;
	var input;
	input = SoundIn.ar([0, 1]);
	Out.ar(out, input * (wet - 1));
	Out.ar(bus, input * wet);
}).add;

// effect Synths

SynthDef(\reverb, {
	arg in = 20, out = 0, wet = 0.5;
	var input, reverb;

	input = In.ar(in);
	reverb = FreeVerb.ar(input, wet, 0.7);
	Out.ar(out, reverb);
}).add;

)



// chopped recording to buffer
(
~recorder = {

// different buffer for multiple loops
arg buffer, chop = true;
var numPieces, duration, offset, record, bufferLength, routine;

	bufferLength = buffer.numFrames;

	if(chop == true, {
		//chopped recording
		//amount of sound snippets
		numPieces = [4, 6, 8, 12, 16, 32].choose;
		("numPieces:" + numPieces).postln;

		//duration of each sound snippet and break inbetween
		duration = (0.5 * bufferLength / numPieces).floor;

		routine = Routine{
			for (0, numPieces, {
				arg i;
				offset = i * 2 * duration;
				record = Synth(\recBuf, [\out, 0, \bufnum, buffer.bufnum, \offset, offset, \duration, duration]);
				(duration/44100).wait;
				record.run(false);
			});
			"recording finished".postln;
		}.play;
	},{
		//unchopped recording
		routine = Routine{
			record = Synth(\recBuf, [\out, 0, \bufnum, buffer.bufnum]);
			(bufferLength/44100).wait;
			record.run(false);
			"recording finished".postln;
		}.play;
	});

};
)

// global buffer variables
(
~beatLoop = Buffer.alloc(s, 44100 * 1.0, 2);
~loop1 = Buffer.alloc(s, 44100 * 8.0, 2);
~loop2 = Buffer.alloc(s, 44100 * 16.0, 2);
)

// play buffer; start before recording

~loop1Play = Synth(\playBuf, [\bufnum, ~loop1.bufnum, \out, 0]);
~loop2Play = Synth(\playBuf, [\bufnum, ~loop2.bufnum]);
~beatloopPlay = Synth(\playBuf, [\bufnum, ~beatLoop.bufnum]);

// loop control
~loop1Play.run(false);
~loop1Play.run(true);

~loop2Play.run(false);
~loop2Play.run(true);

~beatLoopPlay.run(false);
~beatLoopPlay.run(true);

~loop1Play.free;
~loop2Play.free;
~beatLoopPlay.free;


// record loops
~recorder.value(~loop1, true);
~recorder.value(~loop1, false);
~recorder.value(~loop2, true);
~recorder.value(~loop2, true);
~recorder.value(~beatLoop, true);

// plot a buffers
~beatLoop.plot;


// other input
// pitchfollowing Synth
~kazoo = Synth(\pitchCake, [\out, 0, \bus, 20, \wet, 0]);
~kazoo.free;

// audio (mic) input
~audioIn = Synth(\AudioIn);
~audioIn.free;


// effects
//reverb on kazoo Synth
~reverbKazoo =  Synth.after(1, \reverb, [\in, 20]);
~reverbKazoo.free;

// control busses for wet signal and amp in Kazoo synth
~busKazooWet = Bus.control(s, 1);
~busKazooWet.set(0.9);
~kazoo.map(\wet, ~busKazooWet);

~busKazooAmp = Bus.control(s, 1);
~busKazooAmp.set(10);
~kazoo.map(\ampMul, ~busKazooAmp);

//reverb on AudioIn
~reverbAudioIn = Synth.after(1, \reverb, [\in, 22]);
~reverbAudioIn.free;

// control bus for wet signal in AudioIn;
~busAudioInWet = Bus.control(s, 1);
~audioIn.map(\wet, ~busAudioInWet);

~busAudioInWet.set(0.5);

// reverb on whole output
~reverbOut = Synth.after(1, \reverb, [\in, 0]);
~reverbOut.free;

//recording to file
s.recChannels = 2;
s.recSampleFormat = 'int24';
s.recHeaderFormat = 'wav';
s.prepareForRecord;

s.record;
s.stopRecording;

// free buffer
~loop1.free;
~loop2.free;
~beatLoop.free;