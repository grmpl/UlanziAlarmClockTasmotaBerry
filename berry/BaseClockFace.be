import introspect

class BaseClockFace
    var clockfaceManager
    var matrixController

    var hasValue
    var value

    def init(clockfaceManager)
        log(classname(self) + "Init",3);

        self.clockfaceManager = clockfaceManager;
        self.matrixController = clockfaceManager.matrixController;
    end

    def deinit()
        log(classname(self)+ "DeInit",3);
    end


    def render()
        self.matrixController.clear()
    end

end

return BaseClockFace
