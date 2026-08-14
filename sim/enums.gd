class_name E
# Doc 1 §2 — all enums, in one autoload-free static class.
# Action identity is deliberately NOT an enum: it is a StringName (&"kill",
# &"take_job") so actions register as data; the ActionRegistry is the source
# of truth.

enum Goal { AMBITION, SECURITY, WEALTH, STANDING, LOYALTY, VENGEANCE }
# LOYALTY and VENGEANCE are target-indexed; the others are scalars.

enum Trait {
	RECKLESS, PARANOID, OBSERVANT, CRAVEN, BRUTAL, SLY,
	LOYAL, AMBITIOUS, GREEDY, CALCULATING
}

enum ActionTag { VIOLENCE, DECEPTION, SOCIAL, ECONOMIC, INVESTIGATIVE, PUBLIC }

enum Visibility { OPEN, PRIVATE, ANONYMOUS, ATTRIBUTED }

enum TraceKind { EYEWITNESS, PHYSICAL, HEARSAY, MOTIVE, ABSENCE }

enum Field { ACTOR, ACTION, TARGET, INSTRUMENT }

enum Verdict { DISMISSED, DEMOTED, EXILED, KILLED }

enum CharState { ACTIVE, DEAD, EXILED }

# Defined in doc 3 §1 (as a standalone enum there); lives here because doc 1 §2
# makes this class the single home for sim enums.
enum JobOutcome { PENDING, SUCCESS, PARTIAL, FAILURE, DISASTER }
