import slappy
import sequtils

slappyInit()
var 
  sources:seq[tuple[name:string,source:Source]]
  listener = Listener()

proc playSound*(sound:string) =
  let soundSource = sources.mapIt(it.name).find(sound)
  if soundSource < 0:
    let 
      soundFile = "sounds\\"&sound&".wav"
      source = newSound(soundFile).play()
    sources.add (sound,source)
  else:
    sources[soundSource].source.stop()
    sources[soundSource].source.play()

proc setVolume*(vol:float32) =
  listener.gain = vol

proc closeSound* =
  slappyClose()

proc volume*:float32 = listener.gain

