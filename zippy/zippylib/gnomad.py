import subprocess, argparse, sys, re, os, logging, shutil, gzip
from . import files
logger = logging.getLogger(__name__)


class GnomadChromosomeInfo:
    def __init__(self, gnomad_version, info_type, chromosome_id, resources_folder):
        self.gnomad_version = gnomad_version
        self.info_type = info_type
        self.chromosome_id = chromosome_id
        self.vcf_found = False
        self.tbi_found = False
        self.file_basename = f"gnomad.{self.info_type}.r{self.gnomad_version}.sites." + \
            f"{self.chromosome_id}.vcf.bgz"
        self.stripped_file_basename = f"gnomad.{self.info_type}.r{self.gnomad_version}.sites." + \
            f"{self.chromosome_id}.stripped.vcf.bgz"
        self.resources_folder = resources_folder
        self.index_file_txt_fullpath = os.path.join(resources_folder, self.file_basename + ".tbi")
        self.file_fullpath = os.path.join(resources_folder, self.file_basename)
        self.index_file_fullpath = os.path.join(resources_folder, self.file_basename + ".tbi")
        self.stripped_index_file_txt_fullpath = os.path.join(resources_folder,
                                                             self.stripped_file_basename + ".tbi")
        self.stripped_file_fullpath = os.path.join(resources_folder, self.stripped_file_basename)
        self.stripped_file_fullpath_text = os.path.join(resources_folder,
            f"gnomad.{self.info_type}.r{self.gnomad_version}.sites.{self.chromosome_id}.stripped.vcf")

    def gather_file(self, gs_folder, file_basename):
        filefullpath = os.path.join(self.resources_folder, file_basename)
        dest_folder_norm = os.path.normpath(self.resources_folder)
        if os.path.exists(filefullpath):
            # TODO make a checksum
            print(f"skipped {filefullpath}")
        else:
            file_uri = os.path.join(gs_folder, file_basename)
            gsutil_fullpath = os.path.join(args.zippypath, 'venv', 'bin', 'gsutil')
            rsync_cmd = f"TMPDIR={args.zippytmp} {gsutil_fullpath} cp {file_uri} {dest_folder_norm}/"
            logger.info(f"Getting file with command {rsync_cmd}")
            sp = subprocess.Popen(rsync_cmd, shell=True)
            statuscode = sp.wait()
            if statuscode > 0:
                raise Exception("The last gsutil command raised a non-zero status " +
                                f"code of {statuscode}.")

    def gather_data(self):
        assert self.vcf_found and self.tbi_found
        if os.path.exists(self.stripped_file_fullpath):
            logger.info(f"File {self.stripped_file_fullpath} already found")
        else:
            gs_folder = f"gs://gnomad-public/release/{self.gnomad_version}/vcf/{self.info_type}"
            vcf_file = f"{self.file_basename}"
            tbi_file = f"{self.file_basename}.tbi"
            self.gather_file(gs_folder, vcf_file)
            self.gather_file(gs_folder, tbi_file)
            #files.VCF.create_stripped_vcf(self.file_fullpath,
            #                              self.stripped_file_fullpath)
        #self.compress_data(resources_folder, deambiguate=False)
        #self.test_compressed_data(resources_folder)
    def compress_data(self, resources_folder, deambiguate=False):
        if deambiguate:
            shutil.move(self.stripped_file_fullpath, self.stripped_file_fullpath_txt)
        shutil.copy2(self.stripped_file_fullpath, self.stripped_file_fullpath_text)
        with gzip.open(self.stripped_file_fullpath, "wb") as gzipout, open(self.stripped_file_fullpath_text, "rb") as gzipin:
            shutil.copyfileobj(gzipin, gzipout)


def list_files():
    gs_folder = f"gs://gnomad-public/release/{gnomad_version}/vcf/{info_type}"
    sp = subprocess.Popen(f"gsutil ls {gs_folder}", shell=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    statuscode = sp.wait()
    files = list(sp.stdout)
    errors = list(sp.stderr)
    return (statuscode, files, errors)


def get_files(gnomad_version, info_type, resources_folder):
    chromosomes_infos = {}
    #gs_folder = f"gs://gnomad-public/release/{gnomad_version}/vcf/{info_type}"
    #filepartsre = re.compile(f"{gs_folder}/gnomad.{info_type}.r{gnomad_version}.sites.(.*).vcf.bgz(.tbi)?")
    nums = list(range(1, 23))
    nums.append("X")
    #nums.append("Y")
    for num in nums:
        numstr = str(num)
        chromosomes_infos[numstr] = GnomadChromosomeInfo(
            gnomad_version, info_type, numstr, resources_folder)
        chromosomes_infos[numstr].vcf_found = True
        chromosomes_infos[numstr].tbi_found = True
    for (chromid, chromobj) in chromosomes_infos.items():
        chromobj.gather_data()
        #if ".X." in chromobj.file_basename:
        #files.VCF.create_stripped_vcf(chromobj.file_fullpath, chromobj.stripped_file_fullpath)
    return chromosomes_infos


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--version", default="2.1.1")
    parser.add_argument("-r", "--resources_folder", default="/var/local/zippy/resources")
    parser.add_argument("-u", "--user_and_group_string", default=None, type=str)
    parser.add_argument("-z", "--zippypath", default="/usr/local/zippy", type=str)
    parser.add_argument("-t", "--zippytmp", default="/tmp/zippy", type=str)
    args = parser.parse_args()
    get_files(args.version, "genomes", args.resources_folder)
