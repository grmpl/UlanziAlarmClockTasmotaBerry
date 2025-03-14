# small example showing problem discussed in https://github.com/arendst/Tasmota/discussions/23148
class permanent
    def init()
    end
    def dosomething()
        var buffer=bytes()
        for i:1..100
            buffer=buffer..bytes(100)
        end
    end
end

class temporary
    var permclass
    def init(permanent)
        self.permclass=permanent
    end

    def deinit()
        self.permclass.dosomething()
    end
end
    


