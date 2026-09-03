#ifndef JTOneFixTapClassifier_h
#define JTOneFixTapClassifier_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    JTOneFixTapDirectionAmbiguous = 0,
    JTOneFixTapDirectionLeft,
    JTOneFixTapDirectionRight,
} JTOneFixTapDirection;

/*
 * Tracks one physical fixed contact and one physical tapping contact across
 * the whole overlap. Direction is decided from the accumulated projection,
 * never from a release frame. Contact replacement invalidates the sequence;
 * low-confidence geometry is intentionally ignored instead of guessed.
 */
typedef struct {
    int fixedContactID;
    int tappingContactID;
    double signedProjectionSum;
    double absoluteProjectionSum;
    unsigned int sampleCount;
    bool invalid;
} JTOneFixTapClassifier;

#define JT_ONE_FIX_TAP_CLASSIFIER_INITIALIZER \
    { -1, -1, 0.0, 0.0, 0, false }

void JTOneFixTapClassifierReset(JTOneFixTapClassifier *classifier);

bool JTOneFixTapClassifierBegin(JTOneFixTapClassifier *classifier,
                                int fixedContactID,
                                int tappingContactID);

/* Contacts may arrive in either array order. Geometry is already normalized
 * by the engine; leftHanded preserves Jitouch's historical hand-axis mapping.
 */
bool JTOneFixTapClassifierAddSample(JTOneFixTapClassifier *classifier,
                                    int firstContactID,
                                    float firstX,
                                    float firstY,
                                    int secondContactID,
                                    float secondX,
                                    float secondY,
                                    bool leftHanded);

JTOneFixTapDirection JTOneFixTapClassifierDirection(
    const JTOneFixTapClassifier *classifier);

#ifdef __cplusplus
}
#endif

#endif /* JTOneFixTapClassifier_h */
