#include "JTOneFixTapClassifier.h"

#include <math.h>
#include <stddef.h>

/* Normalized trackpad coordinates. These thresholds reject a finger pair
 * lying almost exactly on the historical hand-axis decision boundary.
 */
static const double kMinimumMeanProjection = 0.02;
static const double kMinimumConsistency = 0.60;
static const double kMaximumSampleProjection = 0.50;

void JTOneFixTapClassifierReset(JTOneFixTapClassifier *classifier) {
    if (classifier == NULL) return;
    classifier->fixedContactID = -1;
    classifier->tappingContactID = -1;
    classifier->signedProjectionSum = 0.0;
    classifier->absoluteProjectionSum = 0.0;
    classifier->sampleCount = 0;
    classifier->invalid = false;
}

bool JTOneFixTapClassifierBegin(JTOneFixTapClassifier *classifier,
                                int fixedContactID,
                                int tappingContactID) {
    if (classifier == NULL || fixedContactID < 0 || tappingContactID < 0 ||
        fixedContactID == tappingContactID) {
        return false;
    }
    JTOneFixTapClassifierReset(classifier);
    classifier->fixedContactID = fixedContactID;
    classifier->tappingContactID = tappingContactID;
    return true;
}

bool JTOneFixTapClassifierAddSample(JTOneFixTapClassifier *classifier,
                                    int firstContactID,
                                    float firstX,
                                    float firstY,
                                    int secondContactID,
                                    float secondX,
                                    float secondY,
                                    bool leftHanded) {
    if (classifier == NULL || classifier->invalid ||
        classifier->fixedContactID < 0 || classifier->tappingContactID < 0 ||
        !isfinite(firstX) || !isfinite(firstY) ||
        !isfinite(secondX) || !isfinite(secondY)) {
        if (classifier != NULL) classifier->invalid = true;
        return false;
    }

    double fixedX;
    double fixedY;
    double tappingX;
    double tappingY;
    if (firstContactID == classifier->fixedContactID &&
        secondContactID == classifier->tappingContactID) {
        fixedX = firstX;
        fixedY = firstY;
        tappingX = secondX;
        tappingY = secondY;
    } else if (secondContactID == classifier->fixedContactID &&
               firstContactID == classifier->tappingContactID) {
        fixedX = secondX;
        fixedY = secondY;
        tappingX = firstX;
        tappingY = firstY;
    } else {
        classifier->invalid = true;
        return false;
    }

    /* This is algebraically equivalent to the legacy midpoint comparison,
     * projected onto the user's hand axis, but it is accumulated while both
     * contacts are present instead of recomputed from a drifting release.
     */
    double projection = (fixedX + fixedY) - (tappingX + tappingY);
    if (leftHanded) projection = -projection;
    if (projection > kMaximumSampleProjection) {
        projection = kMaximumSampleProjection;
    } else if (projection < -kMaximumSampleProjection) {
        projection = -kMaximumSampleProjection;
    }
    classifier->signedProjectionSum += projection;
    classifier->absoluteProjectionSum += fabs(projection);
    classifier->sampleCount++;
    return true;
}

JTOneFixTapDirection JTOneFixTapClassifierDirection(
    const JTOneFixTapClassifier *classifier) {
    if (classifier == NULL || classifier->invalid ||
        classifier->sampleCount == 0 ||
        classifier->absoluteProjectionSum <= 0.0) {
        return JTOneFixTapDirectionAmbiguous;
    }

    double mean = classifier->signedProjectionSum /
                  (double)classifier->sampleCount;
    double consistency = fabs(classifier->signedProjectionSum) /
                         classifier->absoluteProjectionSum;
    if (fabs(mean) < kMinimumMeanProjection ||
        consistency < kMinimumConsistency) {
        return JTOneFixTapDirectionAmbiguous;
    }
    return mean > 0.0 ? JTOneFixTapDirectionLeft
                      : JTOneFixTapDirectionRight;
}
