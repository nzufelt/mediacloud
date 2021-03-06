#!/usr/bin/env python3.5

from mediawords.annotator.nyt_labels import NYTLabelsAnnotator
from mediawords.db import connect_to_db
from mediawords.job import AbstractJob, McAbstractJobException, JobBrokerApp
from mediawords.job.nyt_labels.update_story_tags import NYTLabelsUpdateStoryTagsJob
from mediawords.util.log import create_logger
from mediawords.util.perl import decode_object_from_bytes_if_needed

log = create_logger(__name__)


class McNYTLabelsFetchAnnotationJobException(McAbstractJobException):
    """NYTLabelsFetchAnnotationJob exception."""
    pass


class NYTLabelsFetchAnnotationJob(AbstractJob):
    """

    Fetch story's NYTLabels annotation.

    Start this worker script by running:

        ./script/run_in_env.sh ./mediacloud/mediawords/job/nyt_labels/fetch_annotation.py

    """

    @classmethod
    def run_job(cls, stories_id: int) -> None:
        if isinstance(stories_id, bytes):
            stories_id = decode_object_from_bytes_if_needed(stories_id)

        if stories_id is None:
            raise McNYTLabelsFetchAnnotationJobException("'stories_id' is None.")

        stories_id = int(stories_id)

        db = connect_to_db()

        log.info("Fetching annotation for story ID %d..." % stories_id)

        story = db.find_by_id(table='stories', object_id=stories_id)
        if story is None:
            raise McNYTLabelsFetchAnnotationJobException("Story with ID %d was not found." % stories_id)

        nytlabels = NYTLabelsAnnotator()
        try:
            nytlabels.annotate_and_store_for_story(db=db, stories_id=stories_id)
        except Exception as ex:
            raise McNYTLabelsFetchAnnotationJobException(
                "Unable to process story $stories_id with NYTLabels: %s" % str(ex)
            )

        log.info("Adding story ID %d to the update story tags queue..." % stories_id)
        NYTLabelsUpdateStoryTagsJob.add_to_queue(stories_id=stories_id)

        log.info("Finished fetching annotation for story ID %d" % stories_id)

    @classmethod
    def queue_name(cls) -> str:
        return 'MediaWords::Job::NYTLabels::FetchAnnotation'


if __name__ == '__main__':
    app = JobBrokerApp(job_class=NYTLabelsFetchAnnotationJob)
    app.start_worker()
