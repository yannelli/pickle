import Foundation

/// Copy from the web page's render() and renderLife(), keyed off the same pet rules.
enum NestText {
    static func stageLabel(_ pet: WebPet, now: Int64) -> String { PetLife.stage(pet, now: now).rawValue.uppercased() }

    static func age(_ pet: WebPet, now: Int64) -> String {
        let hours = PetLife.age(pet, now: now) / PetLife.HOUR
        return (hours < 24 ? "\(hours)h" : "\(hours / 24)d") + " OLD"
    }

    static func defaultMessage(_ pet: WebPet, now: Int64) -> String {
        if pet.dead { return pet.eaten == true ? "you ate \(pet.name). it was delicious. you monster." : "a good dill. gone, but not forgotten." }
        if pet.sleeping { return pet.energy >= 100 ? "fully rested. dreaming of you." : "shhh. marinating in a dream." }
        if pet.sick { return "feeling sour. get all meters to 30." }
        if pet.fullness < 30 { return "a sip of brine would be divine." }
        if pet.energy < 20 { return "one sleepy pickle. time for a nap." }
        if pet.hygiene < 40 { return "a little funky in here. clean up?" }
        if pet.happiness < 30 { return "a little pet or play would help. ♥" }
        let hour = Int(PetLife.age(pet, now: now) / PetLife.HOUR % 4)
        if PetLife.teen(pet, now: now) != nil {
            return ["ugh. whatever. (still loves you.)", "it’s not a phase. okay, it’s a phase.", "do not talk to me before brine.", "can i get a bigger jar."][hour]
        }
        return ["just a pickle. having a day.", "life is pretty dill-ightful.", "small, salty, and so loved.", "no thoughts. just brine."][hour]
    }

    static func hint(_ pet: WebPet, bites: Int?) -> String {
        if pet.dead { return pet.eaten == true ? "burp. every ending is a new beginning" : "every ending is a new beginning" }
        if let bites { return bites > 0 ? "chomp again... if you dare" : "NEVER · NOPE · CHOMP" }
        return pet.sleeping ? "tap your pickle to rise & brine" : "tap your pickle for +8 happy ♥"
    }

    static func kind(_ pet: WebPet, now: Int64) -> String {
        let days = Int(PetLife.age(pet, now: now) / PetLife.DAY)
        let look: String
        if let elder = PetLife.elder(pet, now: now) { look = elder.name }
        else if let teen = PetLife.teen(pet, now: now) { look = teen.name.lowercased() + " pickle" }
        else { look = PetLife.stage(pet, now: now).rawValue + " pickle" }
        return PickleVariety.of(pet.variety).name + " · " + look + " · \(days)" + (days == 1 ? " day old" : " days old")
    }

    static func quip(_ pet: WebPet, now: Int64) -> String {
        if pet.dead { return pet.eaten == true ? "A good dill. A great snack. A questionable choice." : "A good dill. A very good friend." }
        if let elder = PetLife.elder(pet, now: now) { return elder.quip }
        if let teen = PetLife.teen(pet, now: now) { return teen.quip }
        switch PetLife.stage(pet, now: now) {
        case .baby: return "Small pickle. Enormous feelings."
        case .young: return "Growing into those big dill dreams."
        default: return "Thriving. Mostly thinking about snacks."
        }
    }

    static func careOutlook(_ pet: WebPet, now: Int64) -> String {
        if pet.dead { return "You can start a new little life whenever you’re ready." }
        if pet.sick { return "A little care will help: bring all four meters to 30." }
        let hours = max(0, Int(((PetLife.nextCareAt(pet, now: now) - Double(now)) / Double(PetLife.HOUR)).rounded(.toNearestOrAwayFromZero)))
        return "A daily check-in is plenty. " + (hours <= 2 ? "A little care would be lovely now." : "Comfortably brined for about \(hours) more hours.")
    }

    static func growthOutlook(_ pet: WebPet, now: Int64) -> String {
        if let elder = PetLife.elder(pet, now: now) { return "A new elder look every 3 days. No age limit. Lap \(elder.lap)." }
        if PetLife.teen(pet, now: now) != nil { return "A new teen phase every day. Adult at 7 days, elder at 14." }
        return "Baby → young at 1 day → teen at 3 days → adult at 7 days → elder at 14 days."
    }

    static func eldersUnlocked(_ pet: WebPet, now: Int64) -> Int { PetLife.elder(pet, now: now)?.unlocked ?? 0 }

    static func hatchRemaining(_ pet: WebPet) -> Int {
        max(0, Int((Double(pet.hatchAt - pet.updatedAt) / 1000).rounded(.up)))
    }
}
